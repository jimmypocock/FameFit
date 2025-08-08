//
//  ProfileCreationTests.swift
//  FameFitTests
//
//  Integration tests for profile creation flow
//

import CloudKit
import XCTest
@testable import FameFit

final class ProfileCreationTests: XCTestCase {
    private var container: DependencyContainer!
    private var authManager: (any AuthenticationManaging)?
    private var profileService: (any UserProfileServicing)?
    private var cloudKitManager: (any CloudKitManaging)?
    private var testUsername: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use test/mock setup for integration tests
        let mockAuth = MockAuthenticationManager()
        let mockCloudKit = MockCloudKitManager()
        mockCloudKit.mockIsAvailable = true
        mockCloudKit.currentUserID = "test-user-\(UUID().uuidString)"
        
        container = DependencyContainer()
        
        // For integration tests, we want to use the real profile service with mock dependencies
        profileService = UserProfileService(cloudKitManager: mockCloudKit)
        authManager = mockAuth
        cloudKitManager = mockCloudKit
        
        // Generate unique test username
        testUsername = "test_\(UUID().uuidString.prefix(8))".lowercased()
    }
    
    override func tearDown() async throws {
        // Clean up test profile if it exists
        if let testUsername = testUsername {
            let resetTool = DeveloperResetTool()
            try? await resetTool.deleteProfileByUsername(testUsername)
        }
        
        try await super.tearDown()
    }
    
    func testProfileCreationFlow() async throws {
        // Skip if not running in simulator with iCloud signed in
        guard ProcessInfo.processInfo.environment["SKIP_CLOUDKIT_TESTS"] == nil else {
            throw XCTSkip("Skipping CloudKit tests")
        }
        
        // 1. Simulate user authentication
        if let mockAuth = authManager as? MockAuthenticationManager {
            mockAuth.userID = "test-user-\(UUID().uuidString)"
            mockAuth.userName = "Test User"
            mockAuth.isAuthenticated = true
        }
        
        // 2. Wait for CloudKit to initialize
        var attempts = 0
        while cloudKitManager!.currentUserID == nil && attempts < 20 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }
        
        XCTAssertNotNil(cloudKitManager!.currentUserID, "CloudKit should be initialized")
        
        // 3. Check username availability
        let isAvailable = try await profileService!.isUsernameAvailable(testUsername)
        XCTAssertTrue(isAvailable, "Test username should be available")
        
        // 4. Create profile
        let profile = UserProfile(
            id: UUID().uuidString,
            userID: cloudKitManager!.currentUserID!,
            username: testUsername,
            bio: "Test bio",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )
        
        let createdProfile = try await profileService!.createProfile(profile)
        XCTAssertEqual(createdProfile.username, testUsername)
        
        // 5. Verify profile exists
        let fetchedProfile = try await profileService!.fetchCurrentUserProfile()
        XCTAssertEqual(fetchedProfile.username, testUsername)
        XCTAssertEqual(fetchedProfile.userID, cloudKitManager!.currentUserID)
        
        // 6. Verify username is now taken
        let isStillAvailable = try await profileService!.isUsernameAvailable(testUsername)
        XCTAssertFalse(isStillAvailable, "Username should now be taken")
    }
    
    func testProfileUserConnection() async throws {
        // Skip if not running in simulator with iCloud signed in
        guard ProcessInfo.processInfo.environment["SKIP_CLOUDKIT_TESTS"] == nil else {
            throw XCTSkip("Skipping CloudKit tests")
        }
        
        // Create a profile and verify it's connected to the current user
        if let mockAuth = authManager as? MockAuthenticationManager {
            mockAuth.userID = "test-user-\(UUID().uuidString)"
            mockAuth.isAuthenticated = true
        }
        
        // Wait for CloudKit
        var attempts = 0
        while cloudKitManager!.currentUserID == nil && attempts < 20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        let userID = cloudKitManager!.currentUserID!
        
        let profile = UserProfile(
            id: UUID().uuidString,
            userID: userID,
            username: testUsername,
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )
        
        _ = try await profileService!.createProfile(profile)
        
        // Fetch by current user should return the profile
        let fetchedProfile = try await profileService!.fetchCurrentUserProfile()
        XCTAssertEqual(fetchedProfile.userID, userID)
        XCTAssertEqual(fetchedProfile.username, testUsername)
    }
    
    func testDuplicateUsernameRejection() async throws {
        // Skip if not running in simulator with iCloud signed in
        guard ProcessInfo.processInfo.environment["SKIP_CLOUDKIT_TESTS"] == nil else {
            throw XCTSkip("Skipping CloudKit tests")
        }
        
        if let mockAuth = authManager as? MockAuthenticationManager {
            mockAuth.isAuthenticated = true
        }
        
        // Wait for CloudKit
        var attempts = 0
        while cloudKitManager!.currentUserID == nil && attempts < 20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        
        // Create first profile
        let profile1 = UserProfile(
            id: UUID().uuidString,
            userID: cloudKitManager!.currentUserID!,
            username: testUsername,
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )
        
        _ = try await profileService!.createProfile(profile1)
        
        // Try to create second profile with same username
        let profile2 = UserProfile(
            id: UUID().uuidString,
            userID: "different-user",
            username: testUsername, // Same username
            bio: "",
            workoutCount: 0,
            totalXP: 0,
            joinedDate: Date(),
            lastUpdated: Date(),
            isVerified: false,
            privacyLevel: .publicProfile,
            profileImageURL: nil,
            headerImageURL: nil
        )
        
        do {
            _ = try await profileService!.createProfile(profile2)
            XCTFail("Should not allow duplicate username")
        } catch ProfileServiceError.usernameAlreadyTaken {
            // Expected
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
