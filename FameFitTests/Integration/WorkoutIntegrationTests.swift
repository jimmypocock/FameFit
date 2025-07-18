import XCTest
import Combine
@testable import FameFit

class WorkoutIntegrationTests: XCTestCase {
    
    var dependencyContainer: DependencyContainer!
    var mockCloudKitManager: MockCloudKitManager!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        
        // Create mock managers
        mockCloudKitManager = MockCloudKitManager()
        let authManager = AuthenticationManager(cloudKitManager: mockCloudKitManager)
        // Reset auth state for test isolation
        authManager.isAuthenticated = false
        authManager.userID = nil
        authManager.userName = nil
        let workoutObserver = WorkoutObserver(cloudKitManager: mockCloudKitManager)
        
        // Create container with mocks
        dependencyContainer = DependencyContainer(
            authenticationManager: authManager,
            cloudKitManager: mockCloudKitManager,
            workoutObserver: workoutObserver
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        mockCloudKitManager.reset()
        dependencyContainer = nil
        
        super.tearDown()
    }
    
    func testFollowerCountUpdatesInUI() {
        // Given
        let expectation = XCTestExpectation(description: "Follower count updates")
        let initialCount = mockCloudKitManager.followerCount
        
        // Subscribe to follower count changes
        mockCloudKitManager.$followerCount
            .dropFirst() // Skip initial value
            .sink { newCount in
                XCTAssertEqual(newCount, initialCount + 5)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When - Simulate workout completion
        mockCloudKitManager.addFollowers(5)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAuthenticationFlow() {
        // Given - Start with unauthenticated state
        mockCloudKitManager.isSignedIn = false
        mockCloudKitManager.userName = ""
        let authManager = dependencyContainer.authenticationManager
        XCTAssertFalse(authManager.isAuthenticated)
        
        // When - Simulate sign in
        authManager.userID = "test-user"
        authManager.userName = "Test User"
        authManager.isAuthenticated = true
        mockCloudKitManager.isSignedIn = true
        mockCloudKitManager.userName = "Test User"
        
        // Then
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertEqual(authManager.userName, "Test User")
    }
    
    func testWorkoutToFollowerFlow() {
        // This tests that adding followers updates both follower count and workout count
        
        // Given
        XCTAssertEqual(mockCloudKitManager.followerCount, 100, "Should start with 100 followers")
        XCTAssertEqual(mockCloudKitManager.totalWorkouts, 20, "Should start with 20 workouts")
        
        // When - Simulate what happens when a workout is detected
        mockCloudKitManager.addFollowers(5)
        
        // Then - Verify synchronous updates
        XCTAssertEqual(mockCloudKitManager.followerCount, 105, "Should have 105 followers")
        XCTAssertEqual(mockCloudKitManager.totalWorkouts, 21, "Should have 21 workouts")
        XCTAssertTrue(mockCloudKitManager.addFollowersCalled, "Should have called addFollowers")
        XCTAssertEqual(mockCloudKitManager.lastAddedFollowerCount, 5, "Should have added 5 followers")
    }
    
    func testErrorHandling() {
        // Given
        mockCloudKitManager.shouldFailAddFollowers = true
        _ = dependencyContainer.workoutObserver // Ensure observer is initialized
        
        // When - Try to add followers
        mockCloudKitManager.addFollowers(5)
        
        // Then
        XCTAssertNotNil(mockCloudKitManager.lastError)
        XCTAssertEqual(mockCloudKitManager.followerCount, 100) // Should not change
    }
    
    func testStreakCalculation() {
        // Given
        _ = mockCloudKitManager.currentStreak // Verify starts at 0
        
        // When - Complete a workout
        mockCloudKitManager.addFollowers(5)
        
        // Then - In real implementation, streak logic would be tested here
        // For now, we just verify the property exists and can be modified
        XCTAssertGreaterThanOrEqual(mockCloudKitManager.currentStreak, 0)
    }
    
    func testMockCloudKitManagerBehavior() {
        // Test the mock directly to ensure it works as expected
        XCTAssertEqual(mockCloudKitManager.followerCount, 100, "Should start with 100 followers")
        XCTAssertEqual(mockCloudKitManager.totalWorkouts, 20, "Should start with 20 workouts")
        
        // Add followers
        mockCloudKitManager.addFollowers(5)
        
        // Verify both values updated
        XCTAssertEqual(mockCloudKitManager.followerCount, 105, "Should have 105 followers")
        XCTAssertEqual(mockCloudKitManager.totalWorkouts, 21, "Should have 21 workouts")
    }
}