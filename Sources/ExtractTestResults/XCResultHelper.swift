//
//  XCResultHelper.swift
//
//
//  Created by José Echagüe on 7/6/23.
//

import Foundation

import XCParseCore
import CollectionConcurrencyKit

import CommonHelpers

struct XCResultHelper {
	let xcresult: XCResult
	let destinationPath: URL
	
	var attachmentsPath: URL { self.destinationPath.appending(path: "Attachments") }
	
	var logsPath: URL { self.destinationPath.appending(path: "Logs") }
	
	private var currentScreenRecordingAttachment: TestAttachment? = nil
	private var currentTestStartTime: Date! = nil
	
	init(xcresult: XCResult, destinationPath: URL) {
		self.xcresult = xcresult
		self.destinationPath = destinationPath
	}
	
	mutating func testSuiteResults(from record: XCParseCore.ActionRecord) async throws -> TestSuiteResults {
		guard let testRef = record.actionResult.testsRef else {
			throw Error.preconditionViolation(description: "The XCRecord is not a test results bundle")
		}
		
		let runDestination = Self.runDestination(from: record.runDestination)
		let testStatus = Bool(testStatus: record.actionResult.status) ?? false
		
		guard let testPlanRunSummaries: ActionTestPlanRunSummaries = testRef.modelFromReference(withXCResult: xcresult) else {
			throw Error.executionError(description: "Unhandled test reference type \(String(describing: testRef.targetType?.getType()))")
		}
		
		func extractSubtests(from test: ActionTestSummaryIdentifiableObject) -> [ActionTestMetadata] {
			if let test = test as? ActionTestMetadata {
				return [test]
			}
			
			if let test = test as? ActionTestSummaryGroup {
				return test.subtests.flatMap { extractSubtests(from: $0) }
			}
			
			return []
		}
		
		let tests = testPlanRunSummaries.summaries.flatMap { summary in
			summary.testableSummaries.flatMap { testable in
				testable.tests.flatMap { test -> [ActionTestMetadata] in
					guard let test = test as? ActionTestSummaryGroup else { return [] }
					
					return test.subtests.flatMap { extractSubtests(from: $0) }
				}
			}
		}
		
		self.currentTestStartTime = record.startedTime
		
		let testResults = try await tests.asyncMap { try await self.testResults(from: $0) }
		
		return .init(name: record.testPlanName ?? record.title ?? record.schemeCommandName,
					 startTime: record.startedTime,
					 duration: DateInterval(start: record.startedTime, end: record.endedTime).duration ,
					 successful: testStatus,
					 runDestination: runDestination,
					 tests: testResults)
	}
	
	func extractLogs(from record: XCParseCore.ActionRecord) throws {
		let logsExtractionPath = self.logsPath
		
		func extract(id: String, logName: String) throws {
			let path = logsExtractionPath.appending(path: logName)
			try XCAttachmentHelper.extract(id: id, type: .directory, to: path, from: self.xcresult)
			
			// Remove unneded logs
			if let testPlanName = record.testPlanName {
				let fileManager = FileManager.default
				let contents = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: [])
				for item in contents {
					if !item.lastPathComponent.hasPrefix(testPlanName) {
						try fileManager.removeItem(at: item)
					}
				}
			}
		}
		
		if let buildDiagnosticsRef = record.buildResult.diagnosticsRef {
			try extract(id: buildDiagnosticsRef.id, logName: "Build")
		}
		
		if let actionDiagnosticsRef = record.actionResult.diagnosticsRef {
			try extract(id: actionDiagnosticsRef.id, logName: "Test")
		}
		
		try Self.flattenDirectoryTree(at: logsExtractionPath)
	}
}
	
private extension XCResultHelper {
	mutating func testResults(from testRecord: XCParseCore.ActionTestMetadata) async throws -> TestResult {
		guard let summaryRef = testRecord.summaryRef,
			  let testSummary: ActionTestSummary = summaryRef.modelFromReference(withXCResult: xcresult) else {
			throw Error.executionError(description: "Unhandled test summary type \(String(describing: testRecord.summaryRef?.targetType?.getType()))")
		}
		
		return .init(name: testRecord.name,
					 startTime: testSummary.activitySummaries.first?.start,
					 duration: testRecord.duration,
					 successful: testRecord.testStatus == "Success",
					 steps: try await steps(fromTest: testSummary))
	}
	
	mutating func steps(fromTest testSummary: ActionTestSummary) async throws -> [TestStep] {
		let activitySummaries = try await steps(fromActivities: testSummary.activitySummaries)
		
		for activitySummary in activitySummaries.filter({ !($0.attachments?.isEmpty ?? false) }) {
			if let videoAttachment = Self.firstVideoAttachment(from: activitySummary.attachments!) {
				self.currentScreenRecordingAttachment = videoAttachment
				self.currentTestStartTime = activitySummary.startTime
				break
			}
		}
		
		defer {
			if self.currentScreenRecordingAttachment != nil {
				self.currentScreenRecordingAttachment = nil
				self.currentTestStartTime = .distantPast
			}
		}
		
		let failureSummaries = try await steps(fromActivities: testSummary.failureSummaries)
			
		let steps = activitySummaries + failureSummaries
		
		return steps.sorted { $0.startTime <= $1.startTime }
	}
	
	func steps(fromActivities activitiesSummaries: [ActionTestActivitySummary]) async throws -> [TestStep] {
		try await activitiesSummaries.asyncMap { try await step(fromActivity: $0) }
	}
	
	func steps(fromActivities activitiesSummaries: [ActionTestFailureSummary]) async throws -> [TestStep] {
		try await activitiesSummaries.asyncMap { try await step(fromActivity: $0) }
	}
	
	func step(fromActivity activitySummary: ActionTestActivitySummary) async throws -> TestStep {
		let stepStartTime = activitySummary.start ?? .now
		
		let stepAttachments = await attachments(from: activitySummary.attachments, parentActivityStartTime: stepStartTime)
		
		return .init(name: activitySummary.title,
					 uuid: activitySummary.uuid,
					 activityType: TestActivityType(rawValue: activitySummary.activityType) ?? .unknown,
					 startTime: stepStartTime,
					 duration: activitySummary.finish?.timeIntervalSince(activitySummary.start ?? .distantFuture),
					 successful: activitySummary.failureSummaryIDs.isEmpty,
					 attachments: stepAttachments,
					 substeps: try await steps(fromActivities: activitySummary.subactivities))
	}
	
	func step(fromActivity failureSummary: ActionTestFailureSummary) async throws -> TestStep {
		let stepStartTime = failureSummary.timestamp ?? .now
		
		var failureAttachments = await attachments(from: failureSummary.attachments, parentActivityStartTime: stepStartTime)
		
		let failureName = failureSummary.message ?? failureSummary.uuid
		
		if let currentScreenRecordingAttachment, let currentTestStartTime {
			// Add screenshot at failure timestamp
			
			let filename = FileNameUtils.imageFilename(from: currentScreenRecordingAttachment.filename!)
			let attachmentTimestamp = failureSummary.timestamp!.timeIntervalSince(currentTestStartTime)
			try await currentScreenRecordingAttachment.extractImage(to: self.attachmentsPath,
																	withFilename: filename,
																	at: attachmentTimestamp, from: xcresult)
			failureAttachments.append(.init(name: failureName,
											uuid: failureSummary.uuid,
											uniformTypeIdentifier: .png,
											timestamp: attachmentTimestamp,
											filename: filename,
											userInfo: nil))
		}
		
		return .init(name: failureSummary.message ?? failureSummary.uuid,
					 uuid: failureSummary.uuid,
					 activityType: .userCreated,
					 startTime: stepStartTime,
					 duration: .zero,
					 successful: false,
					 attachments: failureAttachments,
					 substeps: nil)
	}
	
	private static func firstVideoAttachment(from attachments: [TestAttachment]) -> TestAttachment? {
		attachments.first { $0.uniformTypeIdentifier == .mpeg4 }
	}
	
	func attachments(from attachments: any Sequence<ActionTestAttachment>, parentActivityStartTime: Date) async -> [TestAttachment] {
		await attachments.asyncCompactMap { attachment in
			let attachmentTypeIdentifier = UniformTypeIdentifier.init(rawValue: attachment.uniformTypeIdentifier) ?? .unknown
			
			guard attachmentTypeIdentifier != .eventRecord else { return nil }
			
			let userInfo: [String : AnyCodable]?
			if let _userInfo = attachment.userInfo {
				userInfo = .init(uniqueKeysWithValues: _userInfo.storage.compactMap {
					($0.key, $0.value) as? (String, AnyCodable)
				})
			} else {
				userInfo = nil
			}

#if DEBUG
			precondition(![UniformTypeIdentifier.eventRecord, .unknown].contains(attachmentTypeIdentifier), "Attempting to extract unusable attachment type")
#endif
			
			return TestAttachment.init(name: attachment.name,
									   uuid: attachment.uuid,
									   uniformTypeIdentifier: attachmentTypeIdentifier,
									   timestamp: attachment.timestamp?.timeIntervalSince(parentActivityStartTime),
									   filename: attachment.filename,
									   userInfo: userInfo,
									   rawAttachment: attachment,
									   needsExtraction: true)
		}
	}
	
	static func runDestination(from record: XCParseCore.ActionRunDestinationRecord) -> RunDestination? {
		guard let targetDeviceRecord = deviceRecord(from: record.targetDeviceRecord),
			  let localComputerRecord = deviceRecord(from: record.localComputerRecord) else {
			return nil
		}
		
		return .init(targetDeviceRecord: targetDeviceRecord,
					 localComputerRecord: localComputerRecord,
					 targetSDKRecord: getSDKRecord(from: record.targetSDKRecord))
	}
	
	static func deviceRecord(from record: XCParseCore.ActionDeviceRecord) -> DeviceRecord? {
		guard let architecture = DeviceRecord.CPUArchitecture(rawValue: record.nativeArchitecture),
			  let platformIdentifier = URL(string: record.platformRecord.identifier) else {
			return nil
		}
		
		return .init(displayName: record.name,
					 targetArchitecture: architecture,
					 osVersion: record.operatingSystemVersionWithBuildNumber,
					 modelName: record.modelName,
					 modelCode: record.modelCode,
					 identifier: record.identifier,
					 platformIdentifier: platformIdentifier,
					 platformName: record.platformRecord.userDescription)
	}

	static func getSDKRecord(from record: XCParseCore.ActionSDKRecord) -> SDKRecord {
		return .init(name: record.name, identifier: record.identifier, osVersion: record.operatingSystemVersion)
	}
	
	static func flattenDirectoryTree(at parentDirectoryPath: URL) throws {
		let parentDirectoryEnumerator = try FileManager.default.contentsOfDirectory(at: parentDirectoryPath, includingPropertiesForKeys: nil)
		
		guard parentDirectoryEnumerator.count == 1, let singleChildPath = parentDirectoryEnumerator.first, singleChildPath.hasDirectoryPath else { return }
		
		try moveContents(of: singleChildPath, to: parentDirectoryPath)
		
		try FileManager.default.removeItem(at: singleChildPath)
		
		try flattenDirectoryTree(at: parentDirectoryPath)
	}
	
	private static func moveContents(of sourcePath: URL, to destinationPath: URL) throws {
		for childURL in try FileManager.default.contentsOfDirectory(at: sourcePath, includingPropertiesForKeys: nil) {
			let destinationFileURL = destinationPath.appendingPathComponent(childURL.lastPathComponent)
			
			try FileManager.default.moveItem(at: childURL, to: destinationFileURL)
		}
	}
}
