//
//  ImageUtils.swift
//
//
//  Created by José Echagüe on 8/9/23.
//

import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public struct ImageUtils {
	
	@discardableResult
	public static func write(image: CGImage, to path: URL) -> Bool {
		guard let imageDestination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
		
		CGImageDestinationAddImage(imageDestination, image, nil)
		
		return CGImageDestinationFinalize(imageDestination)
	}
}
