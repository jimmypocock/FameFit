//
//  Logger.swift
//  FameFit
//
//  Centralized logging utility for FameFit
//

import Foundation
import os.log

// MARK: - Simple Logger Implementation for Watch App Compatibility

struct FameFitLogger {
    
    // MARK: - Log Categories
    
    static let cloudKit = "CloudKit"
    static let workout = "Workout"
    static let auth = "Authentication"
    static let social = "Social"
    static let notifications = "Notifications"
    static let sync = "Sync"
    static let healthKit = "HealthKit"
    static let ui = "UI"
    static let app = "App"
    static let data = "Data"
    static let general = "General"
    
    // MARK: - OSLog Instances
    
    private static let logs: [String: OSLog] = [
        cloudKit: OSLog(subsystem: "com.jimmypocock.FameFit", category: "CloudKit"),
        workout: OSLog(subsystem: "com.jimmypocock.FameFit", category: "Workout"),
        auth: OSLog(subsystem: "com.jimmypocock.FameFit", category: "Authentication"),
        social: OSLog(subsystem: "com.jimmypocock.FameFit", category: "Social"),
        notifications: OSLog(subsystem: "com.jimmypocock.FameFit", category: "Notifications"),
        sync: OSLog(subsystem: "com.jimmypocock.FameFit", category: "Sync"),
        healthKit: OSLog(subsystem: "com.jimmypocock.FameFit", category: "HealthKit"),
        ui: OSLog(subsystem: "com.jimmypocock.FameFit", category: "UI"),
        app: OSLog(subsystem: "com.jimmypocock.FameFit", category: "App"),
        data: OSLog(subsystem: "com.jimmypocock.FameFit", category: "Data"),
        general: OSLog(subsystem: "com.jimmypocock.FameFit", category: "General")
    ]
    
    // MARK: - Logging Methods
    
    static func debug(_ message: String, category: String = general) {
        let log = logs[category] ?? logs[general]!
        os_log(.debug, log: log, "%{public}@", message)
    }
    
    static func info(_ message: String, category: String = general) {
        let log = logs[category] ?? logs[general]!
        os_log(.info, log: log, "%{public}@", message)
    }
    
    static func notice(_ message: String, category: String = general) {
        let log = logs[category] ?? logs[general]!
        os_log(.default, log: log, "%{public}@", message)
    }
    
    static func warning(_ message: String, category: String = general) {
        let log = logs[category] ?? logs[general]!
        os_log(.error, log: log, "⚠️ %{public}@", message)
    }
    
    static func error(_ message: String, error: Error? = nil, category: String = general) {
        let log = logs[category] ?? logs[general]!
        
        if let error = error {
            os_log(.error, log: log, "❌ %{public}@: %{public}@", message, error.localizedDescription)
        } else {
            os_log(.error, log: log, "❌ %{public}@", message)
        }
    }
    
    static func fault(_ message: String, error: Error? = nil, category: String = general) {
        let log = logs[category] ?? logs[general]!
        
        if let error = error {
            os_log(.fault, log: log, "💥 %{public}@: %{public}@", message, error.localizedDescription)
        } else {
            os_log(.fault, log: log, "💥 %{public}@", message)
        }
    }
}