//
//  ExtractTestResultsArguments.swift
//
//
//  Created by José Echagüe on 8/7/23.
//

import Foundation

import ArgumentParser
import CommonHelpers

internal struct ExtractTestResultsArguments : ParsableArguments {
	@Argument(help: "XCResult path")
	var xcresultPath: URL
	
	@Argument(help: "Destination path. Defaults to current directory")
	var destinationPath: URL?
	
	@Flag(name: [.customLong("extract-logs")], help: "Extract console logs")
	var extractLogs: Bool = false
}
