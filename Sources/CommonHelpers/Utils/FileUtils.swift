//
//  FileUtils.swift
//
//
//  Created by José Echagüe on 9/12/23.
//

import Foundation

public struct FileUtils {
	public static func zipContentsOfDirectory(at directoryURL: URL, to destinationURL: URL) throws {
		let coordinator = NSFileCoordinator()
		var error: NSError?
		var _error: Swift.Error?
		
		coordinator.coordinate(readingItemAt: directoryURL, options: .forUploading, error: &error) { tmpURL in
			do {
				try FileManager.default.moveItem(at: tmpURL, to: destinationURL)
			} catch {
				_error = error
			}
		}
		
		if let error { throw error }
		if let _error { throw _error }
	}
}
