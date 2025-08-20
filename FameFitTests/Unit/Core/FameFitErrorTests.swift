@testable import FameFit
import XCTest

class FameFitErrorTests: XCTestCase {


    func testUserFriendlyMessages() {
        // Test that errors provide user-friendly messages without technical details
        let errors: [FameFitError] = [
            .healthKitNotAvailable,
            .healthKitAuthorizationDenied,
            .workoutSessionFailed(NSError(domain: "technical", code: 999)),
            .cloudKitNotAvailable,
            .cloudKitUserNotFound,
            .cloudKitSyncFailed(NSError(domain: "technical", code: 500)),
            .unknownError(NSError(domain: "technical", code: -1))
        ]

        for error in errors {
            let message = error.userFriendlyMessage
            XCTAssertFalse(message.isEmpty, "Error should have a user-friendly message")
            XCTAssertFalse(message.contains("technical"), "User message should not contain technical details")
            XCTAssertFalse(message.contains("Error Domain"), "User message should not contain error domain")
        }
    }
}
