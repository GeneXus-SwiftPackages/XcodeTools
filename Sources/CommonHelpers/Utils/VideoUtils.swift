//
//  VideoUtils.swift
//
//
//  Created by José Echagüe on 8/9/23.
//

import AVFoundation
import CoreGraphics
import Foundation

public struct VideoUtils {
	public static func extractFrame(at timestamp: TimeInterval, from videoFile: URL) async throws -> CGImage? {
		let videoAsset = AVAsset(url: videoFile)
		let time = CMTimeMakeWithSeconds(timestamp, preferredTimescale: 1)
		
		let generator = AVAssetImageGenerator(asset: videoAsset)
		generator.requestedTimeToleranceBefore = .zero
		generator.requestedTimeToleranceAfter = .zero
		
		let generatedThumbnail = try await generator.image(at: time)
		
		return generatedThumbnail.image
	}
}
