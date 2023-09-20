//
//  File.swift
//  
//
//  Created by José Echagüe on 8/8/23.
//

import Foundation

// MARK: - Errors

public enum Error: Swift.Error, LocalizedError {
	case executionError(description: String)
	
	case preconditionViolation(description: String)
	
	case warning(description: String)
}
