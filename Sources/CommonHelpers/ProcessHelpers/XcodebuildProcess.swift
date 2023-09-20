//
//  XcodebuildProcess.swift
//  
//
//  Created by José Echagüe on 8/14/23.
//

import Foundation

import TSCBasic

public struct XcodebuildProcess {
	private static let COMMAND_NAME = "xcodebuild"
	
	let projectPath: URL
	let projectConfiguration: Configuration
	
	let scheme: String
	
	let clonedSourcePackagesPath: URL?
	let symRoot: URL?
	
	public init(projectPath: URL, projectConfiguration: Configuration = .release, scheme: String, clonedSourcePackagesPath: URL? = nil, symRoot: URL? = nil) {
		self.projectPath = projectPath
		self.projectConfiguration = projectConfiguration
		self.scheme = scheme
		self.clonedSourcePackagesPath = clonedSourcePackagesPath
		self.symRoot = symRoot
	}
	
	internal func setupProcess(for action: XcodebuildAction,
							   withDestionation destination: String? = nil,
							   resultsPath: URL? = nil,
							   additionalArguments: [String]?,
							   withEnvironment enviromentVars: [String : String]?) -> TSCBasic.Process {
		var xcodebuildArguments = ["xcrun", Self.COMMAND_NAME, "clean", action.rawValue,
								   "-project", self.projectPath.relativePath,
								   "-configuration", self.projectConfiguration.rawValue,
								   "-scheme", self.scheme,
								   "-skipPackageUpdates",
								   "-disableAutomaticPackageResolution"]
		if let resultsPath {
			xcodebuildArguments.append(contentsOf: ["-resultBundlePath", resultsPath.relativePath])
		}
		
		if let destination {
			xcodebuildArguments.append(contentsOf: ["-destination", destination])
		}
		
		if let clonedSourcePackagesPath {
			xcodebuildArguments.append(contentsOf: ["-clonedSourcePackagesDirPath", clonedSourcePackagesPath.relativePath])
		}
		
		if let symRoot {
			xcodebuildArguments.append("SYMROOT=\(symRoot.relativePath)")
		}
		
		if let additionalArguments {
			xcodebuildArguments.append(contentsOf: additionalArguments)
		}
		
		return Process(arguments: xcodebuildArguments, environment: enviromentVars ?? [:])
	}
	
	private static let TEST_RESULTS_PATH_REGEX = #/Test session results, code coverage, and logs:\n\t(?<path>.*)\n/#
	
	public typealias ProcessResult = (exitCode: Int32, stdOutput: String?, stdError: String?)
	
	private func internalExecuteTestAction(withDestionation destination: String,
										  resultsPath: URL?,
										  testNames: [String]?,
										  withEnvironment enviromentVars: [String : String]?) -> Result<ProcessResult, Swift.Error> {
		let xcodebuildProcess = self.setupTestAction(withDestionation: destination, resultsPath: resultsPath, testNames: testNames, withEnvironment: enviromentVars)
		
		let result: TSCBasic.ProcessResult
		do {
			try xcodebuildProcess.launch()
			result = try xcodebuildProcess.waitUntilExit()
		} catch {
			return .failure(error)
		}
		
		switch result.exitStatus {
		case let .terminated(code: code):
			let stdOutput = try? result.utf8Output()
			let stderrOutput = try? result.utf8stderrOutput()
			
			return .success((exitCode: code, stdOutput: stdOutput, stdError: stderrOutput))
			
		case let .signalled(signal: signal):
			return .failure(XcodebuildError.init(underlyingError: ProcessError.signalExit(XcodebuildProcess.COMMAND_NAME, signal),
												 stdError: try? result.utf8stderrOutput()))
		}
	}
	
	public func executeTestAction(withDestionation destination: String,
								  resultsPath: URL?,
								  testNames: [String]?,
								  withEnvironment enviromentVars: [String : String]?) -> Result<URL, Swift.Error> {
		let result = self.internalExecuteTestAction(withDestionation: destination, resultsPath: resultsPath, testNames: testNames, withEnvironment: enviromentVars)
		
		switch result {
		case .success(let processResult):
			guard let stdOutput = processResult.stdOutput else {
				return .failure(Error.executionError(description: "Unable to get standard output from xcodebuild execution (exit code: \(processResult.exitCode))"))
			}
			
			guard let pathMatch = stdOutput.firstMatch(of: XcodebuildProcess.TEST_RESULTS_PATH_REGEX) else {
				writeToStdOutput(stdOutput)
				if let stdError = processResult.stdError { writeToStdError(stdError) }
				return .failure(Error.executionError(description: "Unable to match test results path in command output"))
			}
			
			return .success(.init(string: String(pathMatch.path))!)
			
		case .failure(let error):
			return .failure(error)
		}
	}
	
	func setupTestAction(withDestionation destination: String,
						 resultsPath: URL?,
						 testNames: [String]?,
						 withEnvironment enviromentVars: [String : String]?) -> TSCBasic.Process {
		var additionalArguments: [String]? = nil
		
		if let testNames {
			additionalArguments = testNames.map { "-only-testing:\($0)"}
		}
		
		return self.setupProcess(for: .test, withDestionation: destination, resultsPath: resultsPath,
								 additionalArguments: additionalArguments, withEnvironment: enviromentVars)
	}
}

@frozen public enum Configuration : String {
	case debug = "Debug"
	case release = "Release"
}

enum XcodebuildAction: String {
	case build = "build"
	case test = "test"
}

struct XcodebuildError : Swift.Error {
	let underlyingError: Swift.Error
	let stdError: String?
}

enum ProcessError: Swift.Error, LocalizedError {
	case nonZeroExit(String, Int32)
	case signalExit(String, Int32)
	case errorThrown(String, Swift.Error)

	var errorDescription: String? {
		switch self {
		case let .nonZeroExit(command, code):
			return "\(command) exited with a non-zero code: \(code)"
		case let .signalExit(command, signal):
			return "\(command) exited due to signal: \(signal)"
		case let .errorThrown(command, error):
			return "\(command) returned unexpected error: \(error)"
		}
	}
}
