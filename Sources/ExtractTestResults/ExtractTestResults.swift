//
//  ExtractTestResults.swift
//
//
//  Created by José Echagüe on 7/6/23.
//

import Foundation

import XCParseCore
import ArgumentParser

import CommonHelpers

@main
struct ExtractTestResuts: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Extract test results from an XCResult bundle")
	
	@OptionGroup var arguments: ExtractTestResultsArguments
}

extension ExtractTestResuts {
	mutating func run() async throws {
		
		var xcresult = XCResult(path: self.arguments.xcresultPath.relativePath)
		
		let outterDestinationPath = arguments.destinationPath ?? URL(filePath: (FileManager.default.currentDirectoryPath as String))
		let destinationPath = outterDestinationPath.appendingPathComponent("TestResults")
		
		guard let invocationRecord = xcresult.invocationRecord else {
			throw Error.executionError(description: "\(xcresult.path) does not appear to be an xcresult")
		}
		
		var xcResultHelper = XCResultHelper(xcresult: xcresult, destinationPath: destinationPath)
		
		try Self.ensureExistance(directories: [destinationPath, xcResultHelper.attachmentsPath, xcResultHelper.destinationPath],
								 createIfNotExists: true)
		
#if DEBUG
		print("Extracting test results to: \(destinationPath.relativePath)")
#endif
		
		let actions = invocationRecord.actions.filter { $0.actionResult.testsRef != nil }
		for action in actions {
			let testSuite = try await xcResultHelper.testSuiteResults(from: action)
			
			let jsonEncoder = JSONEncoder()
			jsonEncoder.outputFormatting = .prettyPrinted
			jsonEncoder.dateEncodingStrategy = .iso8601
			
			let jsonData = try jsonEncoder.encode(testSuite)
			let jsonString = String(data: jsonData, encoding: .utf8)!
			
			let jsonPath = destinationPath.appending(path: testSuite.name).appendingPathExtension("json")
			
			try jsonString.write(to: jsonPath, atomically: false, encoding: .utf8)
			
			XCAttachmentHelper.extract(attachments: testSuite.allAttachments, to: xcResultHelper.attachmentsPath, from: xcresult)
			
			if arguments.extractLogs {
				try xcResultHelper.extractLogs(from: action)
			}
		}
		
		let testResultsZipPath = outterDestinationPath.appending(component: "testResults.zip")
		try FileUtils.zipContentsOfDirectory(at: destinationPath, to: testResultsZipPath)
		
		print("Test results extraction finished successfully")
		print("Results at: \(testResultsZipPath.relativePath)")
	}
}

private extension ExtractTestResuts {
	@discardableResult
	static func ensureExistance(directories: [URL], createIfNotExists: Bool = true) throws -> Bool {
		for directory in directories {
			if try !self.ensureExistance(directory, createIfNotExists: createIfNotExists) {
				return false
			}
		}
		
		return true
	}
	
	@discardableResult
	private static func ensureExistance(_ directory: URL, createIfNotExists: Bool = true) throws -> Bool {
		if !FileManager.default.fileExists(atPath: directory.relativePath) {
			if createIfNotExists {
				try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
			} else {
				return false
			}
		}
		
		return true
	}
}
