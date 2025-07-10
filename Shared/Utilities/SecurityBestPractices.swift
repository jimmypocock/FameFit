import Foundation
import HealthKit

/// Security best practices for FameFit
/// This file documents and implements security measures for handling sensitive health data
enum SecurityBestPractices {
    
    // MARK: - Data Privacy
    
    /// Never log sensitive health data in production
    static func sanitizeHealthDataForLogging(_ workout: HKWorkout) -> String {
        // Only log non-sensitive metadata
        return "Workout: \(workout.workoutActivityType.name) - Duration: \(Int(workout.duration/60)) min"
    }
    
    /// Validate data before processing
    static func isValidWorkout(_ workout: HKWorkout) -> Bool {
        // Ensure workout has reasonable values
        guard workout.duration > 0,
              workout.duration < 86400, // Less than 24 hours
              workout.startDate.timeIntervalSinceNow < 0, // Not in the future
              workout.endDate.timeIntervalSinceNow < 0 // Not in the future
        else {
            return false
        }
        
        // Ensure end date is after start date
        return workout.endDate > workout.startDate
    }
    
    // MARK: - HealthKit Permissions
    
    /// Request only the minimum required permissions
    static let requiredHealthKitTypes: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [.workoutType()]
        
        // Only add types that exist
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        
        return types
    }()
    
    // MARK: - Error Handling
    
    /// Sanitize error messages to avoid exposing internal details
    static func sanitizeError(_ error: Error) -> String {
        switch error {
        case let fameFitError as FameFitError:
            return fameFitError.userFriendlyMessage
        default:
            // Generic error message for unknown errors
            return "An error occurred. Please try again."
        }
    }
    
    // MARK: - Data Storage
    
    /// Keys for UserDefaults should use reverse domain notation
    enum UserDefaultsKeys {
        static let lastProcessedWorkoutDate = "com.jimmypocock.FameFit.lastProcessedWorkoutDate"
        static let appInstallDate = "com.jimmypocock.FameFit.appInstallDate"
        static let hasCompletedOnboarding = "com.jimmypocock.FameFit.hasCompletedOnboarding"
    }
    
    /// Securely clear sensitive data
    static func clearAllUserData() {
        // Clear UserDefaults
        UserDefaultsKeys.allCases.forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Note: HealthKit and CloudKit data are managed by the system
        // and cleared automatically when the app is deleted
    }
}

// MARK: - Extensions

extension FameFitError {
    /// User-friendly error messages that don't expose internal details
    var userFriendlyMessage: String {
        switch self {
        case .healthKitNotAvailable:
            return "Health data is not available on this device."
        case .healthKitAuthorizationDenied:
            return "Please grant health data permissions in Settings."
        case .workoutSessionFailed:
            return "Unable to start workout session. Please try again."
        case .cloudKitNotAvailable:
            return "iCloud is not available. Please check your settings."
        case .cloudKitUserNotFound:
            return "Unable to access your account. Please sign in to iCloud."
        case .cloudKitSyncFailed:
            return "Unable to sync data. Please check your connection."
        case .unknownError:
            return "An unexpected error occurred. Please try again."
        }
    }
}

extension UserDefaultsKeys {
    static var allCases: [String] {
        return [
            lastProcessedWorkoutDate,
            appInstallDate,
            hasCompletedOnboarding
        ]
    }
}

// MARK: - Security Validation

/// Validates input data to prevent injection or malformed data
struct DataValidator {
    
    /// Validate user input strings
    static func isValidUserInput(_ input: String, maxLength: Int = 100) -> Bool {
        // Check length
        guard input.count <= maxLength else { return false }
        
        // Check for control characters
        let controlCharacterSet = CharacterSet.controlCharacters
        guard input.rangeOfCharacter(from: controlCharacterSet) == nil else { return false }
        
        return true
    }
    
    /// Validate numeric values are within reasonable bounds
    static func isValidFollowerCount(_ count: Int) -> Bool {
        return count >= 0 && count <= 1_000_000
    }
    
    /// Validate workout duration
    static func isValidWorkoutDuration(_ duration: TimeInterval) -> Bool {
        // Between 1 minute and 24 hours
        return duration >= 60 && duration <= 86400
    }
}