//
//  ServiceResolver.swift
//  FameFit
//
//  Resolves service implementations based on runtime environment and configuration
//

import Foundation
import HealthKit

/// ServiceResolver manages dependency resolution and determines which service
/// implementations to use based on runtime environment and configuration
final class ServiceResolver {
    
    // MARK: - Properties
    
    /// Shared instance for singleton access where needed
    static let shared = ServiceResolver()
    
    /// Flag indicating if mock services are active
    static var isUsingMockData: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--mock-healthkit") ||
               ProcessInfo.processInfo.environment["USE_MOCK_HEALTHKIT"] == "1" ||
               UserDefaults.standard.bool(forKey: "UseMockHealthKit")
        #else
        return false
        #endif
    }
    
    // MARK: - Service Resolution
    
    /// Returns the appropriate HealthKit service based on environment
    static var healthKitService: HealthKitProtocol {
        #if DEBUG
        if isUsingMockData {
            return MockHealthKitService.shared
        }
        #endif
        return HealthKitService.shared
    }
    
    // MARK: - Configuration
    
    /// Enables mock services programmatically (DEBUG only)
    static func enableMockServices() {
        #if DEBUG
        UserDefaults.standard.set(true, forKey: "UseMockHealthKit")
        FameFitLogger.info("Mock services enabled", category: FameFitLogger.system)
        #endif
    }
    
    /// Disables mock services programmatically (DEBUG only)
    static func disableMockServices() {
        #if DEBUG
        UserDefaults.standard.set(false, forKey: "UseMockHealthKit")
        FameFitLogger.info("Mock services disabled", category: FameFitLogger.system)
        #endif
    }
    
    /// Resets all mock data (DEBUG only)
    static func resetMockData() {
        #if DEBUG
        if let mockService = healthKitService as? MockHealthKitService {
            mockService.reset()
            MockDataStorage.shared.clearAll()
            FameFitLogger.info("Mock data reset", category: FameFitLogger.system)
        }
        #endif
    }
    
    // MARK: - Debug Information
    
    /// Returns current service configuration for debugging
    static var debugConfiguration: [String: Any] {
        [
            "isUsingMockData": isUsingMockData,
            "healthKitService": String(describing: type(of: healthKitService)),
            "environment": ProcessInfo.processInfo.environment["USE_MOCK_HEALTHKIT"] ?? "not set",
            "launchArguments": ProcessInfo.processInfo.arguments.filter { $0.starts(with: "--") }
        ]
    }
    
    // MARK: - Private Init
    
    private init() {
        #if DEBUG
        // Log service configuration on initialization
        if Self.isUsingMockData {
            FameFitLogger.info("ServiceResolver initialized with MOCK services", category: FameFitLogger.system)
        } else {
            FameFitLogger.info("ServiceResolver initialized with PRODUCTION services", category: FameFitLogger.system)
        }
        #endif
    }
}

// MARK: - Service Extensions

extension HealthKitService {
    /// Shared instance for production HealthKit service
    static let shared = HealthKitService()
}

#if DEBUG
extension MockHealthKitService {
    /// Shared instance for mock HealthKit service
    static let shared = MockHealthKitService()
}
#endif