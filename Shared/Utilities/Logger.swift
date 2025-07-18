//
//  Logger.swift
//  FameFit
//
//  Centralized logging utility for FameFit
//

import Foundation
import os.log

/// Centralized logging for FameFit
struct FameFitLogger {
    // MARK: - Log Categories
    
    /// General app lifecycle and UI events
    static let app = Logger(subsystem: "com.jimmypocock.FameFit", category: "app")
    
    /// Workout tracking and HealthKit operations
    static let workout = Logger(subsystem: "com.jimmypocock.FameFit", category: "workout")
    
    /// CloudKit and data synchronization
    static let cloudKit = Logger(subsystem: "com.jimmypocock.FameFit", category: "cloudkit")
    
    /// Authentication and user management
    static let auth = Logger(subsystem: "com.jimmypocock.FameFit", category: "auth")
    
    /// Error logging
    static let error = Logger(subsystem: "com.jimmypocock.FameFit", category: "error")
    
    // MARK: - Helper Methods
    
    /// Log a debug message
    static func debug(_ message: String, category: Logger = app) {
        category.debug("\(message)")
    }
    
    /// Log an info message
    static func info(_ message: String, category: Logger = app) {
        category.info("\(message)")
    }
    
    /// Log a notice message
    static func notice(_ message: String, category: Logger = app) {
        category.notice("\(message)")
    }
    
    /// Log an error
    static func error(_ message: String, error: Error? = nil, category: Logger = error) {
        if let error = error {
            category.error("\(message): \(String(describing: error))")
        } else {
            category.error("\(message)")
        }
    }
    
    /// Log a fault (critical error)
    static func fault(_ message: String, category: Logger = error) {
        category.fault("\(message)")
    }
}