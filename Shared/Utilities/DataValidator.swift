//
//  DataValidator.swift
//  FameFit
//
//  Input validation and data sanitization utilities
//

import Foundation
import HealthKit

/// Validates and sanitizes data to ensure security and correctness
struct DataValidator {
    
    // MARK: - User Input Validation
    
    /// Validate user input strings
    static func isValidUserInput(_ input: String, maxLength: Int = 100) -> Bool {
        // Check length
        guard input.count <= maxLength else { return false }
        
        // Check for control characters
        let controlCharacterSet = CharacterSet.controlCharacters
        guard input.rangeOfCharacter(from: controlCharacterSet) == nil else { return false }
        
        return true
    }
    
    // MARK: - Numeric Validation
    
    /// Validate follower count is within reasonable bounds
    static func isValidFollowerCount(_ count: Int) -> Bool {
        return count >= 0 && count <= 1_000_000
    }
    
    /// Validate workout duration
    static func isValidWorkoutDuration(_ duration: TimeInterval) -> Bool {
        // Between 1 minute and 24 hours
        return duration >= 60 && duration <= 86400
    }
    
    // MARK: - Workout Validation
    
    /// Validate workout data before processing
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
    
    // MARK: - Data Sanitization
    
    /// Sanitize workout data for logging (remove PII)
    static func sanitizeWorkoutForLogging(_ workout: HKWorkout) -> String {
        // Only log non-sensitive metadata
        let activityType = String(describing: workout.workoutActivityType).replacingOccurrences(of: "HKWorkoutActivityType.", with: "")
        return "Workout: \(activityType) - Duration: \(Int(workout.duration/60)) min"
    }
    
    /// Sanitize error messages to avoid exposing internal details
    static func sanitizeError(_ error: Error) -> String {
        if let fameFitError = error as? FameFitError {
            return fameFitError.userFriendlyMessage
        }
        // Generic error message for unknown errors
        return "An error occurred. Please try again."
    }
}