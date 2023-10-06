//
//  DataTypes.swift
//
//
//  Created by José Echagüe on 7/13/23.
//

import Foundation

import XCParseCore

import CommonHelpers

struct TestSuiteResults: Codable {
	let name: String
	let startTime: Date
	let duration: TimeInterval
	let successful: Bool
	
	let runDestination: RunDestination!
	
	let tests: [TestResult]
	
	var allAttachments: [TestAttachment] {
		var testAttachment: [TestAttachment] = []
		
		tests.forEach { test in
			test.steps.forEach { step in
				testAttachment.append(contentsOf: step.allAttachments)
			}
		}
		
		return testAttachment
	}
}

struct TestResult: Codable {
	let name: String?
	let startTime: Date?
	let duration: TimeInterval?
	let successful: Bool
	
	let steps: [TestStep]
	let failures: [TestFailure]
}

struct TestStep: Codable {
	let name: String
	let uuid: String
	let activityType: TestActivityType
	let startTime: Date
	let duration: TimeInterval?
	let successful: Bool
	
	let attachments: [TestAttachment]?
	
	var screenRecordingAttachment: TestAttachment? {
		self.attachments?.first { $0.uniformTypeIdentifier == .mpeg4 }
	}
	
	var allAttachments: [TestAttachment] {
		var allAttachments = self.attachments ?? []
			
		if let substeps {
			substeps.forEach { substep in
				allAttachments.append(contentsOf: substep.allAttachments)
			}
		}
		
		return allAttachments
	}
	
	let substeps: [TestStep]?
}

enum FailureType: String, Codable {
	case AssertionFailure = "Assertion Failure"
	case Unknown
}

struct TestFailure : Codable {
	let uuid: String
	let type: FailureType
	let message: String?
	
	let filePath: String?
	let lineNumber: Int?
	
	let timestamp: Date?
}

struct TestAttachment : Codable {
	let name: String?
	let uuid: String?
	let uniformTypeIdentifier: UniformTypeIdentifier
	let timestamp: TimeInterval?
	let filename: String?
	
	let userInfo: [String : AnyCodable]?
	
	var rawAttachment: ActionTestAttachment?
	var needsExtraction: Bool?

	enum CodingKeys: String, CodingKey {
		case name, uuid, uniformTypeIdentifier, timestamp, filename, userInfo
	}
}

enum TestActivityType : String, Codable {
	case `internal` = "com.apple.dt.xctest.activity-type.internal"
	case userCreated = "com.apple.dt.xctest.activity-type.userCreated"
	
	case unknown = "com.genexus.ios.activity-type.unknown"
}

enum UniformTypeIdentifier : String, Codable {
	// Images
	case png = "public.png"
	
	// Video
	case mpeg4 = "public.mpeg-4"
	
	// Others
	case eventRecord = "com.apple.dt.xctest.synthesized-event-record"
	
	case unknown = "com.genexus.ios.uniform-type.unknown"
}

struct RunDestination : Codable {
	let targetDeviceRecord: DeviceRecord
	let localComputerRecord: DeviceRecord
	let targetSDKRecord: SDKRecord
}

struct DeviceRecord : Codable {
	let displayName: String
	let targetArchitecture: CPUArchitecture
	let osVersion: String
	let modelName: String
	let modelCode: String
	let identifier: String
	let platformIdentifier: URL
	let platformName: String
	
	enum CPUArchitecture : String, Codable {
		case arm64 = "arm64"
		case amr64e = "arm64e"
		case x86_64 = "x86_64"
	}
}

struct SDKRecord : Codable {
	let name: String
	let identifier: String
	let osVersion: String
}

internal extension Bool {
	init?(testStatus: String) {
		switch testStatus {
		case "success":
			self = true
		case "failed":
			self = false
		default:
			return nil
		}
	}
}
