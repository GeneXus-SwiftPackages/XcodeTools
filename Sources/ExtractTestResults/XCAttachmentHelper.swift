//
//  main.swift
//
//
//  Created by José Echagüe on 7/6/23.
//

import Foundation

import CommonHelpers

import XCParseCore 

internal struct XCAttachmentHelper {
	
	static func extract(attachments: [TestAttachment], to path: URL, from xcresult: XCResult) {
		for attachment in attachments.filter({ $0.needsExtraction ?? false }) {
			self.extract(attachment: attachment, to: path, from: xcresult)
		}
	}
	
	static func extract(attachment: TestAttachment, to path: URL, from xcresult: XCResult) {
		guard let rawAttachment = attachment.rawAttachment else { preconditionFailure("A reference to the ActionTestAttachment is needed for extraction") }
		
		self.internalExtract(attachment: rawAttachment, to: path, from: xcresult)
	}
	
	@discardableResult
	static func internalExtract(attachment: ActionTestAttachment, to path: URL, from xcresult: XCResult) -> XCResultToolCommand.Export {
		let exportOperation = XCResultToolCommand.Export(withXCResult: xcresult, attachment: attachment, outputPath: path.relativePath)
		exportOperation.run()
		
		return exportOperation
	}
	
	static func extract(id: String, type: XCResultToolCommand.Export.ExportType, to path: URL, from xcresult: XCResult) throws {
		if !FileManager.default.fileExists(atPath: path.relativePath) {
			try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
		}
		
		let extractOperation = XCResultToolCommand.Export(withXCResult: xcresult, id: id, outputPath: path.relativePath, type: type)
		extractOperation.run()
	}
}

extension ActionTestAttachment {
	var requiresConversion: Bool {
		switch self.uniformTypeIdentifier {
		case UniformTypeIdentifier.eventRecord.rawValue:
			return true
			
		default:
			return false
		}
	}
}
