import Foundation

enum FameFitError: LocalizedError, Equatable {
    // CloudKit Errors
    case cloudKitNotAvailable
    case cloudKitSyncFailed(Error)
    case cloudKitUserNotFound
    case cloudKitNetworkError

    // HealthKit Errors
    case healthKitNotAvailable
    case healthKitAuthorizationDenied
    case healthKitDataNotFound

    // Authentication Errors
    case authenticationFailed(Error)
    case authenticationCancelled
    case userNotAuthenticated

    // Workout Errors
    case workoutSessionFailed(Error)
    case workoutDataCorrupted

    // General Errors
    case networkUnavailable
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .cloudKitNotAvailable:
            "iCloud is not available. Please check your iCloud settings."
        case let .cloudKitSyncFailed(error):
            "Failed to sync data: \(error.localizedDescription)"
        case .cloudKitUserNotFound:
            "User record not found. Please try signing in again."
        case .cloudKitNetworkError:
            "Network error. Please check your connection and try again."
        case .healthKitNotAvailable:
            "Health data is not available on this device."
        case .healthKitAuthorizationDenied:
            "Health data access was denied. Please grant permission in Settings."
        case .healthKitDataNotFound:
            "No health data found."
        case let .authenticationFailed(error):
            "Sign in failed: \(error.localizedDescription)"
        case .authenticationCancelled:
            "Sign in was cancelled."
        case .userNotAuthenticated:
            "Please sign in to continue."
        case let .workoutSessionFailed(error):
            "Workout session failed: \(error.localizedDescription)"
        case .workoutDataCorrupted:
            "Workout data appears to be corrupted."
        case .networkUnavailable:
            "No network connection available."
        case let .unknownError(error):
            "An unexpected error occurred: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .cloudKitNotAvailable:
            "Go to Settings > [Your Name] > iCloud and ensure iCloud is enabled."
        case .cloudKitSyncFailed:
            "Try again later or check your internet connection."
        case .cloudKitUserNotFound:
            "Sign out and sign back in to recreate your user profile."
        case .cloudKitNetworkError:
            "Check your Wi-Fi or cellular connection."
        case .healthKitNotAvailable:
            "This feature requires an iPhone or Apple Watch."
        case .healthKitAuthorizationDenied:
            "Go to Settings > Privacy & Security > Health > FameFit and enable all permissions."
        case .healthKitDataNotFound:
            "Complete a workout to see your data."
        case .authenticationFailed:
            "Try signing in again."
        case .authenticationCancelled:
            "Tap Sign in with Apple to continue."
        case .userNotAuthenticated:
            "Use Sign in with Apple to create your account."
        case .workoutSessionFailed:
            "Try starting your workout again."
        case .workoutDataCorrupted:
            "Start a new workout session."
        case .networkUnavailable:
            "Connect to Wi-Fi or enable cellular data."
        case .unknownError:
            "Try again or contact support if the problem persists."
        }
    }

    /// User-friendly error messages that don't expose internal details
    var userFriendlyMessage: String {
        switch self {
        case .healthKitNotAvailable:
            "Health data is not available on this device."
        case .healthKitAuthorizationDenied:
            "Please grant health data permissions in Settings."
        case .healthKitDataNotFound:
            "No health data found. Please try again."
        case .workoutSessionFailed:
            "Unable to start workout session. Please try again."
        case .workoutDataCorrupted:
            "Workout data is invalid. Please try again."
        case .cloudKitNotAvailable:
            "iCloud is not available. Please check your settings."
        case .cloudKitUserNotFound:
            "Unable to access your account. Please sign in to iCloud."
        case .cloudKitSyncFailed:
            "Unable to sync data. Please check your connection."
        case .cloudKitNetworkError:
            "Network error. Please check your connection."
        case .authenticationFailed:
            "Sign in failed. Please try again."
        case .authenticationCancelled:
            "Sign in was cancelled."
        case .userNotAuthenticated:
            "Please sign in to continue."
        case .networkUnavailable:
            "No internet connection. Please check your network."
        case .unknownError:
            "An unexpected error occurred. Please try again."
        }
    }
}

// Error handling utilities
extension Error {
    var fameFitError: FameFitError {
        if let fameFitError = self as? FameFitError {
            return fameFitError
        }

        // Convert common errors to FameFitError
        let nsError = self as NSError

        switch nsError.domain {
        case "CKErrorDomain":
            switch nsError.code {
            case 1: // Network unavailable
                return .cloudKitNetworkError
            case 11: // Unknown item
                return .cloudKitUserNotFound
            default:
                return .cloudKitSyncFailed(self)
            }
        case "com.apple.healthkit":
            return .healthKitDataNotFound
        default:
            return .unknownError(self)
        }
    }
}

// MARK: - Equatable implementation for testing

extension FameFitError {
    static func == (lhs: FameFitError, rhs: FameFitError) -> Bool {
        switch (lhs, rhs) {
        case (.cloudKitNotAvailable, .cloudKitNotAvailable),
             (.cloudKitUserNotFound, .cloudKitUserNotFound),
             (.cloudKitNetworkError, .cloudKitNetworkError),
             (.healthKitNotAvailable, .healthKitNotAvailable),
             (.healthKitAuthorizationDenied, .healthKitAuthorizationDenied),
             (.healthKitDataNotFound, .healthKitDataNotFound),
             (.authenticationCancelled, .authenticationCancelled),
             (.userNotAuthenticated, .userNotAuthenticated),
             (.workoutDataCorrupted, .workoutDataCorrupted),
             (.networkUnavailable, .networkUnavailable):
            true

        case let (.cloudKitSyncFailed(error1), .cloudKitSyncFailed(error2)),
             let (.authenticationFailed(error1), .authenticationFailed(error2)),
             let (.workoutSessionFailed(error1), .workoutSessionFailed(error2)),
             let (.unknownError(error1), .unknownError(error2)):
            error1.localizedDescription == error2.localizedDescription

        default:
            false
        }
    }
}
