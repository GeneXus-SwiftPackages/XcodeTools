//
//  FileHandlers.swift
//
//
//  Created by José Echagüe on 8/18/23.
//

import Foundation

private var standardError = FileHandle.standardError
private var standardOutput = FileHandle.standardOutput

extension FileHandle: TextOutputStream {
  public func write(_ string: String) {
	let data = Data(string.utf8)
	self.write(data)
  }
}

func writeToStdOutput(_ string: String) { print(string, to: &standardOutput) }

func writeToStdError(_ string: String) { print(string, to: &standardError) }
