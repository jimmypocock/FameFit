//
//  WorkoutVerificationStatus.swift
//  FameFit
//
//  Tracks the verification state of workout challenge contributions
//

import Foundation

/// Detailed verification status for workout challenge links
enum WorkoutVerificationStatus: String, Codable, CaseIterable {
    case pending = "pending"                    // Initial state, awaiting auto-verification
    case autoVerified = "auto_verified"         // Automatically verified via HealthKit
    case manuallyVerified = "manually_verified" // User requested manual verification
    case failed = "failed"                      // Auto-verification failed
    case disputed = "disputed"                  // Another user disputed this contribution
    case graceVerified = "grace_verified"       // Verified during grace period after challenge end
    
    var displayName: String {
        switch self {
        case .pending:
            return "Verifying..."
        case .autoVerified:
            return "Verified"
        case .manuallyVerified:
            return "Manually Verified"
        case .failed:
            return "Verification Failed"
        case .disputed:
            return "Under Review"
        case .graceVerified:
            return "Verified (Grace Period)"
        }
    }
    
    var icon: String {
        switch self {
        case .pending:
            return "clock.arrow.circlepath"
        case .autoVerified:
            return "checkmark.shield.fill"
        case .manuallyVerified:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .disputed:
            return "exclamationmark.bubble.fill"
        case .graceVerified:
            return "checkmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .autoVerified, .graceVerified:
            return "green"
        case .manuallyVerified:
            return "blue"
        case .failed:
            return "red"
        case .disputed:
            return "yellow"
        }
    }
    
    /// Whether this status counts toward challenge progress
    var countsTowardProgress: Bool {
        switch self {
        case .autoVerified, .manuallyVerified, .graceVerified:
            return true
        case .pending, .failed, .disputed:
            return false
        }
    }
    
    /// Whether user can request manual verification in this state
    var canRequestManualVerification: Bool {
        switch self {
        case .failed, .pending:
            return true
        case .autoVerified, .manuallyVerified, .graceVerified, .disputed:
            return false
        }
    }
}

/// Verification configuration for challenges
struct VerificationConfig {
    /// How long to wait for auto-verification before allowing manual request
    static let autoVerificationTimeout: TimeInterval = 30 // 30 seconds
    
    /// Grace period after challenge ends to allow pending verifications
    static let challengeEndGracePeriod: TimeInterval = 3600 // 1 hour
    
    /// Maximum retries for auto-verification
    static let maxAutoVerificationRetries: Int = 3
    
    /// Delay between verification retries
    static let retryDelay: TimeInterval = 10 // 10 seconds
}

/// Verification failure reasons
enum VerificationFailureReason: String, Codable, Error {
    case healthKitDataMissing = "healthkit_missing"
    case dataMismatch = "data_mismatch"
    case impossibleValues = "impossible_values"
    case workoutTooOld = "workout_too_old"
    case challengeEnded = "challenge_ended"
    case timeout = "timeout"
    case unknown = "unknown"
    
    var userMessage: String {
        switch self {
        case .healthKitDataMissing:
            return "Workout data not found in Health app. Please ensure HealthKit permissions are enabled."
        case .dataMismatch:
            return "Workout data doesn't match. Please try manual verification."
        case .impossibleValues:
            return "Workout contains unusual values that need review."
        case .workoutTooOld:
            return "This workout is from before the challenge started."
        case .challengeEnded:
            return "The challenge has already ended."
        case .timeout:
            return "Verification timed out. You can request manual verification."
        case .unknown:
            return "Verification failed. Please try manual verification."
        }
    }
}