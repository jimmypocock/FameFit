import XCTest
import HealthKit
@testable import FameFit

class SecurityTests: XCTestCase {
    
    // MARK: - Data Validation Tests
    
    func testValidWorkoutValidation() {
        // Given - Valid workout
        let validWorkout = TestWorkoutBuilder.createRunWorkout(
            duration: 1800, // 30 minutes
            startDate: Date().addingTimeInterval(-3600) // 1 hour ago
        )
        
        // Then
        XCTAssertTrue(SecurityBestPractices.isValidWorkout(validWorkout))
    }
    
    func testInvalidWorkoutValidation_NegativeDuration() {
        // Given - Workout with end before start
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(-60) // End before start
        
        let invalidWorkout = TestWorkoutBuilder.createWorkout(
            type: .running,
            startDate: startDate,
            endDate: endDate
        )
        
        // Then
        XCTAssertFalse(SecurityBestPractices.isValidWorkout(invalidWorkout))
    }
    
    func testInvalidWorkoutValidation_FutureDate() {
        // Given - Workout in the future
        let futureWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(3600) // 1 hour in future
        )
        
        // Then
        XCTAssertFalse(SecurityBestPractices.isValidWorkout(futureWorkout))
    }
    
    func testInvalidWorkoutValidation_ExcessiveDuration() {
        // Given - Workout longer than 24 hours
        let longWorkout = TestWorkoutBuilder.createRunWorkout(
            duration: 90000, // 25 hours
            startDate: Date().addingTimeInterval(-100000)
        )
        
        // Then
        XCTAssertFalse(SecurityBestPractices.isValidWorkout(longWorkout))
    }
    
    // MARK: - Data Sanitization Tests
    
    func testWorkoutDataSanitization() {
        // Given
        let workout = TestWorkoutBuilder.createRunWorkout(
            duration: 1800,
            distance: 5000,
            calories: 300
        )
        
        // When
        let sanitized = SecurityBestPractices.sanitizeHealthDataForLogging(workout)
        
        // Then
        XCTAssertTrue(sanitized.contains("running"))
        XCTAssertTrue(sanitized.contains("30 min"))
        XCTAssertFalse(sanitized.contains("5000")) // Should not contain raw distance
        XCTAssertFalse(sanitized.contains("300")) // Should not contain raw calories
    }
    
    func testErrorSanitization() {
        // Given
        let healthKitError = FameFitError.healthKitNotAvailable
        let cloudKitError = FameFitError.cloudKitSyncFailed(NSError(domain: "CKError", code: 1))
        let unknownError = NSError(domain: "InternalDomain", code: 999)
        
        // When
        let healthKitMessage = SecurityBestPractices.sanitizeError(healthKitError)
        let cloudKitMessage = SecurityBestPractices.sanitizeError(cloudKitError)
        let unknownMessage = SecurityBestPractices.sanitizeError(unknownError)
        
        // Then
        XCTAssertEqual(healthKitMessage, "Health data is not available on this device.")
        XCTAssertEqual(cloudKitMessage, "Unable to sync data. Please check your connection.")
        XCTAssertEqual(unknownMessage, "An error occurred. Please try again.")
        
        // Should not contain technical details
        XCTAssertFalse(cloudKitMessage.contains("CKError"))
        XCTAssertFalse(unknownMessage.contains("InternalDomain"))
    }
    
    // MARK: - Input Validation Tests
    
    func testValidUserInput() {
        // Given
        let validInputs = [
            "John Doe",
            "test@example.com",
            "Running in the park",
            "123 Main St"
        ]
        
        // Then
        for input in validInputs {
            XCTAssertTrue(DataValidator.isValidUserInput(input))
        }
    }
    
    func testInvalidUserInput() {
        // Given
        let tooLong = String(repeating: "a", count: 101)
        let withControlChars = "Hello\u{0000}World" // Null character
        let withNewlines = "Hello\nWorld\r\n"
        
        // Then
        XCTAssertFalse(DataValidator.isValidUserInput(tooLong))
        XCTAssertFalse(DataValidator.isValidUserInput(withControlChars))
        XCTAssertFalse(DataValidator.isValidUserInput(withNewlines))
    }
    
    func testFollowerCountValidation() {
        // Valid counts
        XCTAssertTrue(DataValidator.isValidFollowerCount(0))
        XCTAssertTrue(DataValidator.isValidFollowerCount(100))
        XCTAssertTrue(DataValidator.isValidFollowerCount(999999))
        
        // Invalid counts
        XCTAssertFalse(DataValidator.isValidFollowerCount(-1))
        XCTAssertFalse(DataValidator.isValidFollowerCount(1_000_001))
    }
    
    func testWorkoutDurationValidation() {
        // Valid durations
        XCTAssertTrue(DataValidator.isValidWorkoutDuration(60)) // 1 minute
        XCTAssertTrue(DataValidator.isValidWorkoutDuration(3600)) // 1 hour
        XCTAssertTrue(DataValidator.isValidWorkoutDuration(86400)) // 24 hours
        
        // Invalid durations
        XCTAssertFalse(DataValidator.isValidWorkoutDuration(59)) // Less than 1 minute
        XCTAssertFalse(DataValidator.isValidWorkoutDuration(86401)) // More than 24 hours
        XCTAssertFalse(DataValidator.isValidWorkoutDuration(-100)) // Negative
    }
    
    // MARK: - UserDefaults Keys Tests
    
    func testUserDefaultsKeysFormat() {
        // All keys should use reverse domain notation
        let keys = SecurityBestPractices.UserDefaultsKeys.allCases
        
        for key in keys {
            XCTAssertTrue(key.hasPrefix("com.jimmypocock.FameFit."))
        }
    }
    
    func testDataClearing() {
        // Given - Set some test data
        UserDefaults.standard.set(Date(), forKey: SecurityBestPractices.UserDefaultsKeys.appInstallDate)
        UserDefaults.standard.set(Date(), forKey: SecurityBestPractices.UserDefaultsKeys.lastProcessedWorkoutDate)
        UserDefaults.standard.set(true, forKey: SecurityBestPractices.UserDefaultsKeys.hasCompletedOnboarding)
        
        // When
        SecurityBestPractices.clearAllUserData()
        
        // Then - All data should be cleared
        XCTAssertNil(UserDefaults.standard.object(forKey: SecurityBestPractices.UserDefaultsKeys.appInstallDate))
        XCTAssertNil(UserDefaults.standard.object(forKey: SecurityBestPractices.UserDefaultsKeys.lastProcessedWorkoutDate))
        XCTAssertNil(UserDefaults.standard.object(forKey: SecurityBestPractices.UserDefaultsKeys.hasCompletedOnboarding))
    }
    
    // MARK: - Permission Scoping Tests
    
    func testMinimalHealthKitPermissions() {
        let requiredTypes = SecurityBestPractices.requiredHealthKitTypes
        
        // Should only request what we need
        XCTAssertTrue(requiredTypes.contains(.workoutType()))
        
        // Should not exceed reasonable count
        XCTAssertLessThanOrEqual(requiredTypes.count, 10)
    }
}