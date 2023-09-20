//
//  URL.swift
//
//
//  Created by José Echagüe on 8/18/23.
//

import Foundation

import ArgumentParser

extension URL : ExpressibleByArgument {
	public init?(argument: String) {
		self = URL.init(fileURLWithPath: argument)
		
		if !self.hasDirectoryPath && !self.pathExtension.isEmpty {
			return nil
		}
	}
}
