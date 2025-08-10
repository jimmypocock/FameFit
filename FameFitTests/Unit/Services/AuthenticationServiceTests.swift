import AuthenticationServices
@testable import FameFit
import XCTest

class AuthenticationServiceTests: XCTestCase {
    private var authManager: AuthenticationService!
    private var mockCloudKitService: MockCloudKitService!

    override func setUp() {
        super.setUp()

        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "FameFitUserID")
        UserDefaults.standard.removeObject(forKey: "FameFitUserName")
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasCompletedOnboarding)

        mockCloudKitService = MockCloudKitService()
        authManager = AuthenticationService(cloudKitManager: mockCloudKitService)
    }

    override func tearDown() {
        authManager = nil
        mockCloudKitService = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.userID)
        XCTAssertNil(authManager.userName)
        XCTAssertFalse(authManager.hasCompletedOnboarding)
    }

    // MARK: - Check Authentication Status Tests

    func testCheckAuthenticationStatusWithNoSavedData() {
        authManager.checkAuthenticationStatus()

        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.userID)
        XCTAssertNil(authManager.userName)
        XCTAssertFalse(authManager.hasCompletedOnboarding)
    }

    func testCheckAuthenticationStatusWithSavedData() {
        // Save test data
        UserDefaults.standard.set("test-user-id", forKey: "FameFitUserID")
        UserDefaults.standard.set("Test User", forKey: "FameFitUserName")
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)

        authManager.checkAuthenticationStatus()

        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertEqual(authManager.userID, "test-user-id")
        XCTAssertEqual(authManager.userName, "Test User")
        XCTAssertTrue(authManager.hasCompletedOnboarding)
    }

    func testCheckAuthenticationStatusWithPartialData() {
        // Save only user ID (missing name)
        UserDefaults.standard.set("test-user-id", forKey: "FameFitUserID")

        authManager.checkAuthenticationStatus()

        // Should not authenticate without both ID and name
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.userID)
        XCTAssertNil(authManager.userName)
    }

    // MARK: - Sign Out Tests

    func testSignOut() {
        // First set up authenticated state
        UserDefaults.standard.set("test-user-id", forKey: "FameFitUserID")
        UserDefaults.standard.set("Test User", forKey: "FameFitUserName")
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        authManager.checkAuthenticationStatus()

        // Verify authenticated
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertTrue(authManager.hasCompletedOnboarding)

        // Sign out
        authManager.signOut()

        // Verify signed out
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.userID)
        XCTAssertNil(authManager.userName)
        XCTAssertFalse(authManager.hasCompletedOnboarding)

        // Verify UserDefaults cleared
        XCTAssertNil(UserDefaults.standard.string(forKey: "FameFitUserID"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "FameFitUserName"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding))
    }

    // MARK: - Complete Onboarding Tests

    func testCompleteOnboarding() {
        XCTAssertFalse(authManager.hasCompletedOnboarding)

        authManager.completeOnboarding()

        XCTAssertTrue(authManager.hasCompletedOnboarding)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding))
    }

    func testCompleteOnboardingPersists() {
        authManager.completeOnboarding()

        // Create new instance to test persistence
        let newAuthManager = AuthenticationService(cloudKitManager: mockCloudKitService)
        newAuthManager.checkAuthenticationStatus()

        // Should still be false because user is not authenticated
        XCTAssertFalse(newAuthManager.hasCompletedOnboarding)

        // But if user is authenticated, it should load the saved value
        UserDefaults.standard.set("test-user-id", forKey: "FameFitUserID")
        UserDefaults.standard.set("Test User", forKey: "FameFitUserName")
        newAuthManager.checkAuthenticationStatus()

        XCTAssertTrue(newAuthManager.hasCompletedOnboarding)
    }

    // MARK: - Security Tests

    func testCannotBypassAuthentication() {
        // Try to complete onboarding without authentication
        authManager.completeOnboarding()

        // Even though onboarding is marked complete in memory
        XCTAssertTrue(authManager.hasCompletedOnboarding)

        // User still cannot access app without authentication
        XCTAssertFalse(authManager.isAuthenticated)
    }

    func testOnboardingFlagDoesNotGrantAuthentication() {
        // Manually set onboarding flag
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)

        authManager.checkAuthenticationStatus()

        // Should still not be authenticated
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertFalse(authManager.hasCompletedOnboarding) // Won't load without auth
    }
}
