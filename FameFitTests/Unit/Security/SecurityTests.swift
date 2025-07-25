@testable import FameFit
import HealthKit
import XCTest

class SecurityTests: XCTestCase {
    // MARK: - Data Validation Tests

    func testValidWorkoutValidation() {
        // Given - Valid workout
        let validWorkout = TestWorkoutBuilder.createRunWorkout(
            duration: 1800, // 30 minutes
            startDate: Date().addingTimeInterval(-3600) // 1 hour ago
        )

        // Then
        XCTAssertTrue(DataValidator.isValidWorkout(validWorkout))
    }

    func testInvalidWorkoutValidation_NegativeDuration() {
        // Test the validator logic directly since HKWorkout throws when dates are invalid
        let validWorkout = TestWorkoutBuilder.createRunWorkout(duration: 1800)
        XCTAssertTrue(DataValidator.isValidWorkout(validWorkout))

        // Test a workout with zero duration
        let zeroWorkout = TestWorkoutBuilder.createRunWorkout(duration: 0)
        XCTAssertFalse(DataValidator.isValidWorkout(zeroWorkout))
    }

    func testInvalidWorkoutValidation_FutureDate() {
        // Given - Workout in the future
        let futureWorkout = TestWorkoutBuilder.createRunWorkout(
            startDate: Date().addingTimeInterval(3600) // 1 hour in future
        )

        // Then
        XCTAssertFalse(DataValidator.isValidWorkout(futureWorkout))
    }

    func testInvalidWorkoutValidation_ExcessiveDuration() {
        // Given - Workout longer than 24 hours
        let longWorkout = TestWorkoutBuilder.createRunWorkout(
            duration: 90000, // 25 hours
            startDate: Date().addingTimeInterval(-100_000)
        )

        // Then
        XCTAssertFalse(DataValidator.isValidWorkout(longWorkout))
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
        let sanitized = DataValidator.sanitizeWorkoutForLogging(workout)

        // Then
        XCTAssertTrue(sanitized.contains("Workout:"))
        XCTAssertTrue(sanitized.contains("Duration: 30 min"))
        XCTAssertFalse(sanitized.contains("5000")) // Should not contain raw distance
        XCTAssertFalse(sanitized.contains("300")) // Should not contain raw calories
    }

    func testErrorSanitization() {
        // Given
        let healthKitError = FameFitError.healthKitNotAvailable
        let cloudKitError = FameFitError.cloudKitSyncFailed(NSError(domain: "CKError", code: 1))
        let unknownError = NSError(domain: "InternalDomain", code: 999)

        // When
        let healthKitMessage = DataValidator.sanitizeError(healthKitError)
        let cloudKitMessage = DataValidator.sanitizeError(cloudKitError)
        let unknownMessage = DataValidator.sanitizeError(unknownError)

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
            "123 Main St",
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
        XCTAssertTrue(DataValidator.isValidFollowerCount(999_999))

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
        let keys = UserDefaultsKeys.allKeys

        for key in keys {
            XCTAssertTrue(key.hasPrefix("com.jimmypocock.FameFit."))
        }
    }

    func testDataClearing() {
        // Given - Set some test data
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.appInstallDate)
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastProcessedWorkoutDate)
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)

        // When
        UserDefaultsKeys.clearAll()

        // Then - All data should be cleared
        XCTAssertNil(UserDefaults.standard.object(forKey: UserDefaultsKeys.appInstallDate))
        XCTAssertNil(UserDefaults.standard.object(forKey: UserDefaultsKeys.lastProcessedWorkoutDate))
        XCTAssertNil(UserDefaults.standard.object(forKey: UserDefaultsKeys.hasCompletedOnboarding))
    }

    // MARK: - Permission Scoping Tests

    func testMinimalHealthKitPermissions() {
        // Test that we're using minimal permissions through RealHealthKitService
        let readTypes = RealHealthKitService.readTypes

        // Should only request what we need
        XCTAssertTrue(readTypes.contains(HKObjectType.workoutType()))

        // Should not exceed reasonable count
        XCTAssertLessThanOrEqual(readTypes.count, 10)
    }
}
