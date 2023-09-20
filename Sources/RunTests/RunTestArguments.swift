//
//  RunTestArguments.swift
//
//
//  Created by José Echagüe on 8/18/23.
//

import Foundation

import ArgumentParser
import CommonHelpers

internal struct RunTestArguments : ParsableArguments {
	@Argument(help: "Project path")
	var projectPath: URL
	
	@Argument(help: "Scheme")
	var schemeName: String
	
	@Argument(help: "Test destination")
	var testDestination: String
	
	@Argument(help: "Tests to run")
	var testNames: [String] = []
	
	@Option(name: [.customShort("c"), .customLong("configuration")],
			help: "Configuration to build: Debug | Release (default)")
	var configuration: Configuration = .release
	
	@Option(name: [.customLong("results-path")])
	var testResultsPath: URL?
	
	@Option(name: [.customLong("swift-packages-path")],
			help: "Path to look for or download Swift Packages")
	var clonedSourcePackagesPath: URL?
	
	@Option(name: [.customLong("xcode-override")],
			help: "Override path of Xcode used by xcrun")
	var xcodePath: URL?
}
