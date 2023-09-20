//
//  RunTests.swift
//
//
//  Created by José Echagüe on 8/14/23.
//

import Foundation

import ArgumentParser
import CommonHelpers

@main
struct RunTests: AsyncParsableCommand {
	static var configuration = CommandConfiguration(abstract: "Extract test results from an XCResult bundle")
	
	@OptionGroup var arguments: RunTestArguments
}

extension RunTests {
	mutating func run() async throws {
		
		guard Self.validate(path: self.arguments.projectPath) else {
			throw Error.preconditionViolation(description: "Project path doesn´t exist")
		}
		
		guard self.arguments.clonedSourcePackagesPath == nil || Self.validate(path: self.arguments.clonedSourcePackagesPath!) else {
			throw Error.preconditionViolation(description: "Swift Packages path is invalid")
		}
		
		var environmentVars: [String:String] = [:]
		
		if let xcodePath = self.arguments.xcodePath {
			guard Self.validate(path: self.arguments.xcodePath!) else { throw Error.preconditionViolation(description: "Invalid Xcode path") }
			
			environmentVars["DEVELOPER_DIR"] = xcodePath.relativePath
		}
		
		let xcodebuild: XcodebuildProcess = .init(projectPath: self.arguments.projectPath,
												  projectConfiguration: self.arguments.configuration,
												  scheme: self.arguments.schemeName,
												  clonedSourcePackagesPath: self.arguments.clonedSourcePackagesPath)

		guard Self.validate(desintation: self.arguments.testDestination) else {
			throw Error.preconditionViolation(description: "Destination argument must be a valid xcodebuild destination")
		}
		
		let testNames = !self.arguments.testNames.isEmpty ? self.arguments.testNames : nil
		
		// PATH variable is needed for finding commands invoked by Xcodebuild (eg. git, basename, etc.).
		if let PathEnvVar = ProcessInfo.processInfo.environment["PATH"] {
			environmentVars["PATH"] = PathEnvVar
		}
		
		var testResultsPath = self.arguments.testResultsPath
		testResultsPath = testResultsPath?.appendingPathComponent("rawOutput.xcresult")
		
		let result = xcodebuild.executeTestAction(withDestionation: self.arguments.testDestination,
												  resultsPath: testResultsPath,
												  testNames: testNames,
												  withEnvironment: environmentVars)

		switch result {
		case .success(let resultsPath):
			print(resultsPath.relativePath)
			
		case .failure(let error):
			throw error
		}

	}
	
	private static func validate(desintation: String) -> Bool {
		// TODO: add more validations
		return !desintation.isEmpty
	}
	
	private static func validate(path: URL) -> Bool {
		// TODO: do something here
		return true
	}
}
