import Foundation

enum FameFitError: LocalizedError {
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
            return "iCloud is not available. Please check your iCloud settings."
        case .cloudKitSyncFailed(let error):
            return "Failed to sync data: \(error.localizedDescription)"
        case .cloudKitUserNotFound:
            return "User record not found. Please try signing in again."
        case .cloudKitNetworkError:
            return "Network error. Please check your connection and try again."
            
        case .healthKitNotAvailable:
            return "Health data is not available on this device."
        case .healthKitAuthorizationDenied:
            return "Health data access was denied. Please grant permission in Settings."
        case .healthKitDataNotFound:
            return "No health data found."
            
        case .authenticationFailed(let error):
            return "Sign in failed: \(error.localizedDescription)"
        case .authenticationCancelled:
            return "Sign in was cancelled."
        case .userNotAuthenticated:
            return "Please sign in to continue."
            
        case .workoutSessionFailed(let error):
            return "Workout session failed: \(error.localizedDescription)"
        case .workoutDataCorrupted:
            return "Workout data appears to be corrupted."
            
        case .networkUnavailable:
            return "No network connection available."
        case .unknownError(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cloudKitNotAvailable:
            return "Go to Settings > [Your Name] > iCloud and ensure iCloud is enabled."
        case .cloudKitSyncFailed:
            return "Try again later or check your internet connection."
        case .cloudKitUserNotFound:
            return "Sign out and sign back in to recreate your user profile."
        case .cloudKitNetworkError:
            return "Check your Wi-Fi or cellular connection."
            
        case .healthKitNotAvailable:
            return "This feature requires an iPhone or Apple Watch."
        case .healthKitAuthorizationDenied:
            return "Go to Settings > Privacy & Security > Health > FameFit and enable all permissions."
        case .healthKitDataNotFound:
            return "Complete a workout to see your data."
            
        case .authenticationFailed:
            return "Try signing in again."
        case .authenticationCancelled:
            return "Tap Sign in with Apple to continue."
        case .userNotAuthenticated:
            return "Use Sign in with Apple to create your account."
            
        case .workoutSessionFailed:
            return "Try starting your workout again."
        case .workoutDataCorrupted:
            return "Start a new workout session."
            
        case .networkUnavailable:
            return "Connect to Wi-Fi or enable cellular data."
        case .unknownError:
            return "Try again or contact support if the problem persists."
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