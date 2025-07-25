@testable import FameFit
import XCTest

class FameFitErrorTests: XCTestCase {
    func testErrorTypes() {
        // Test all error types can be created
        let healthKitError = FameFitError.healthKitNotAvailable
        let authError = FameFitError.healthKitAuthorizationDenied
        let workoutError = FameFitError.workoutSessionFailed(NSError(domain: "test", code: 1))
        let cloudKitNotAvailable = FameFitError.cloudKitNotAvailable
        let cloudKitUserNotFound = FameFitError.cloudKitUserNotFound
        let cloudKitSyncFailed = FameFitError.cloudKitSyncFailed(NSError(domain: "test", code: 2))
        let unknownError = FameFitError.unknownError(NSError(domain: "test", code: 3))

        // Test that all errors have localized descriptions
        XCTAssertNotNil(healthKitError.localizedDescription)
        XCTAssertNotNil(authError.localizedDescription)
        XCTAssertNotNil(workoutError.localizedDescription)
        XCTAssertNotNil(cloudKitNotAvailable.localizedDescription)
        XCTAssertNotNil(cloudKitUserNotFound.localizedDescription)
        XCTAssertNotNil(cloudKitSyncFailed.localizedDescription)
        XCTAssertNotNil(unknownError.localizedDescription)
    }

    func testErrorEquality() {
        // Test error equality
        XCTAssertEqual(FameFitError.healthKitNotAvailable, FameFitError.healthKitNotAvailable)
        XCTAssertEqual(FameFitError.healthKitAuthorizationDenied, FameFitError.healthKitAuthorizationDenied)
        XCTAssertEqual(FameFitError.cloudKitNotAvailable, FameFitError.cloudKitNotAvailable)
        XCTAssertEqual(FameFitError.cloudKitUserNotFound, FameFitError.cloudKitUserNotFound)

        // Test inequality
        XCTAssertNotEqual(FameFitError.healthKitNotAvailable, FameFitError.healthKitAuthorizationDenied)
        XCTAssertNotEqual(FameFitError.cloudKitNotAvailable, FameFitError.cloudKitUserNotFound)
    }

    func testUserFriendlyMessages() {
        // Test that errors provide user-friendly messages without technical details
        let errors: [FameFitError] = [
            .healthKitNotAvailable,
            .healthKitAuthorizationDenied,
            .workoutSessionFailed(NSError(domain: "technical", code: 999)),
            .cloudKitNotAvailable,
            .cloudKitUserNotFound,
            .cloudKitSyncFailed(NSError(domain: "technical", code: 500)),
            .unknownError(NSError(domain: "technical", code: -1)),
        ]

        for error in errors {
            let message = error.userFriendlyMessage
            XCTAssertFalse(message.isEmpty, "Error should have a user-friendly message")
            XCTAssertFalse(message.contains("technical"), "User message should not contain technical details")
            XCTAssertFalse(message.contains("Error Domain"), "User message should not contain error domain")
        }
    }
}
