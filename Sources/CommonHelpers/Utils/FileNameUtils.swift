//
//  FileNameUtils.swift
//
//
//  Created by José Echagüe on 8/10/23.
//

import Foundation

public struct FileNameUtils {
	public static func imageFilename(from filename: String, extension: String = "png") -> String {
		((filename as NSString).deletingPathExtension as NSString).appendingPathExtension(`extension`)!
	}
}
