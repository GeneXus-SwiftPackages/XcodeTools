//
//  ActionTestAttachment+CGImage.swift
//
//
//  Created by José Echagüe on 8/9/23.
//

import CoreGraphics
import Foundation

@testable import XCParseCore // @testable needed to access export output path

import CommonHelpers

extension TestAttachment {
	func extractImage(to path: URL, withFilename filename: String, at timestamp: TimeInterval, from xcresult: XCResult) async throws {
		guard let rawAttachment else { throw Error.preconditionViolation(description: "Attachment must have a ActionTestAttachment refence where to extract images from") }
		
		let exportOperation = XCAttachmentHelper.internalExtract(attachment: rawAttachment, to: path, from: xcresult)
				
		let temporaryFilePath = URL(filePath: exportOperation.outputPath)
		defer {
			try? FileManager.default.removeItem(at: temporaryFilePath)
		}
		
		guard let cgImage = try await VideoUtils.extractFrame(at: timestamp, from: temporaryFilePath) else {
			throw Error.executionError(description: "Unable to extract image thumbnail from video")
		}
		
		let imagePath = path.appending(component: filename)
		ImageUtils.write(image: cgImage, to: imagePath)
	}
}
