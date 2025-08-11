//
//  FameFitLogger.swift
//  FameFit Watch App
//
//  Minimal logging utility for Watch app
//

import Foundation
import os.log

struct FameFitLogger {
    
    // MARK: - Log Categories
    static let workout = "Workout"
    static let healthKit = "HealthKit"
    static let sync = "Sync"
    static let general = "General"
    static let social = "Social"  // Added for GroupWorkout compatibility
    static let connectivity = "Connectivity"  // Added for WatchConnectivity
    
    // MARK: - OSLog Instance
    private static let watchLog = OSLog(subsystem: "com.jimmypocock.FameFit.watchkitapp", category: "Watch")
    
    // MARK: - Logging Methods
    
    static func debug(_ message: String, category: String = general) {
        #if DEBUG
        os_log(.debug, log: watchLog, "[%{public}@] %{public}@", category, message)
        #endif
    }
    
    static func info(_ message: String, category: String = general) {
        os_log(.info, log: watchLog, "[%{public}@] %{public}@", category, message)
    }
    
    static func warning(_ message: String, category: String = general) {
        os_log(.error, log: watchLog, "[%{public}@] ⚠️ %{public}@", category, message)
    }
    
    static func error(_ message: String, error: Error? = nil, category: String = general) {
        if let error = error {
            os_log(.error, log: watchLog, "[%{public}@] ❌ %{public}@: %{public}@", 
                   category, message, error.localizedDescription)
        } else {
            os_log(.error, log: watchLog, "[%{public}@] ❌ %{public}@", category, message)
        }
    }
}