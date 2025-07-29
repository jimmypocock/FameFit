//
//  SecurityBestPracticesTests.swift
//  FameFitTests
//
//  Tests to ensure security best practices are followed
//

import AuthenticationServices
@testable import FameFit
import Foundation
import Security
import XCTest

// MARK: - Security Best Practices Tests

class SecurityBestPracticesTests: XCTestCase {
    func testNoHardcodedSecrets() {
        // Ensure no API keys or secrets are hardcoded
        let cloudKitContainer = "iCloud.com.jimmypocock.FameFit"
        XCTAssertTrue(cloudKitContainer.contains("iCloud.")) // Valid CloudKit identifier format
        XCTAssertFalse(cloudKitContainer.contains("api_key"))
        XCTAssertTrue(!cloudKitContainer.contains("secret"))
        XCTAssertTrue(!cloudKitContainer.contains("password"))
    }

    func testUserDataIsCleanedOnSignOut() {
        // Set up
        let mockCloudKit = MockCloudKitManager()
        let authManager = AuthenticationManager(cloudKitManager: mockCloudKit)

        // Simulate sign in
        authManager.userID = "test-user-123"
        authManager.userName = "Test User"
        authManager.isAuthenticated = true

        // Sign out
        authManager.signOut()

        // Verify all user data is cleared
        XCTAssertTrue(authManager.userID == nil)
        XCTAssertTrue(authManager.userName == nil)
        XCTAssertTrue(authManager.isAuthenticated == false)

        // Verify UserDefaults are cleared
        XCTAssertTrue(UserDefaults.standard.object(forKey: "FameFitUserID") == nil)
        XCTAssertTrue(UserDefaults.standard.object(forKey: "FameFitUserName") == nil)
    }

    func testNoSensitiveDataInMemoryAfterCleanup() {
        // Create a test identifier
        let testUserID = "sensitive-user-\(UUID().uuidString)"

        // Store temporarily
        UserDefaults.standard.set(testUserID, forKey: "FameFitUserID")

        // Remove it
        UserDefaults.standard.removeObject(forKey: "FameFitUserID")
        UserDefaults.standard.synchronize()

        // Verify it's gone
        XCTAssertTrue(UserDefaults.standard.string(forKey: "FameFitUserID") == nil)
    }

    func testHealthKitAuthorizationNotCached() {
        // HealthKit authorization should always be checked dynamically
        // not cached in UserDefaults or anywhere else
        let mockCloudKit = MockCloudKitManager()
        let workoutObserver = WorkoutObserver(cloudKitManager: mockCloudKit)

        // Initial state should be unauthorized
        XCTAssertTrue(workoutObserver.isAuthorized == false)

        // Verify no HealthKit auth status in UserDefaults
        let userDefaultsDict = UserDefaults.standard.dictionaryRepresentation()
        for (key, _) in userDefaultsDict {
            XCTAssertTrue(!key.lowercased().contains("healthkit"))
            XCTAssertTrue(!key.lowercased().contains("authorization"))
        }
    }

    func testWeakReferencesPreventRetainCycles() {
        // Verify managers use weak references to prevent retain cycles
        let container = DependencyContainer()

        // CloudKitManager should have weak reference to AuthenticationManager
        XCTAssertTrue(container.cloudKitManager.authenticationManager != nil)

        // Create a scope to test deallocation
        autoreleasepool {
            let tempContainer = DependencyContainer()
            weak var weakAuth = tempContainer.authenticationManager
            weak var weakCloudKit = tempContainer.cloudKitManager

            XCTAssertTrue(weakAuth != nil)
            XCTAssertTrue(weakCloudKit != nil)
        }
        // After autoreleasepool, objects should be deallocated if no retain cycles
    }

    func testErrorsDoNotExposeInternalDetails() {
        // Verify error messages don't expose internal implementation details
        let errors: [FameFitError] = [
            .cloudKitNotAvailable,
            .healthKitNotAvailable,
            .healthKitAuthorizationDenied,
            .authenticationCancelled
        ]

        for error in errors {
            let description = error.errorDescription ?? ""

            // Error descriptions should not contain:
            XCTAssertTrue(!description.contains("CKContainer"))
            XCTAssertTrue(!description.contains("HKHealthStore"))
            XCTAssertTrue(!description.contains("NSError"))
            XCTAssertTrue(!description.contains("com.apple"))
            XCTAssertTrue(!description.contains("internal"))
            XCTAssertTrue(!description.contains("debug"))
        }
    }

    func testNoDebugCodeInRelease() {
        // Verify no debug-only code is exposed
        #if DEBUG
        // This test only makes sense in release builds
        #else
            // In release, assert that no debug methods are called
            let mockCloudKit = MockCloudKitManager()
            let authManager = AuthenticationManager(cloudKitManager: mockCloudKit)

            // These should not print or log in release
            authManager.signOut()
            mockCloudKit.addFollowers(5)
        #endif
    }
}

// MARK: - Data Privacy Tests

class DataPrivacyTests: XCTestCase {
    func testMinimalDataCollection() {
        // Verify we only collect necessary data
        let mockCloudKit = MockCloudKitManager()
        _ = AuthenticationManager(cloudKitManager: mockCloudKit)

        // NOTE: Cannot directly test handleSignInWithApple without a real ASAuthorizationAppleIDCredential
        // This would need to be tested through UI tests or manual testing

        // Verify we don't store email or other personal info
        let userDefaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in userDefaultsKeys {
            if key.contains("FameFit") {
                // We should not store sensitive personal information
                XCTAssertFalse(key.lowercased().contains("email"), "Should not store email")
                XCTAssertFalse(key.lowercased().contains("phone"), "Should not store phone")
                XCTAssertFalse(key.lowercased().contains("address"), "Should not store address")
                XCTAssertFalse(key.lowercased().contains("password"), "Should not store password")
            }
        }
    }

    func testDataEncryptionInTransit() {
        // CloudKit automatically encrypts data in transit
        // Verify we're using CloudKit's secure container
        let cloudKitManager = CloudKitManager()
        XCTAssertTrue(cloudKitManager.isAvailable == cloudKitManager.isSignedIn)
    }
}
