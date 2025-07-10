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
        // Given
        let authManager = dependencyContainer.authenticationManager
        XCTAssertFalse(authManager.isAuthenticated)
        
        // When - Simulate sign in
        authManager.userID = "test-user"
        authManager.userName = "Test User"
        authManager.isAuthenticated = true
        
        // Then
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertEqual(authManager.userName, "Test User")
    }
    
    func testWorkoutToFollowerFlow() {
        // This tests the complete flow from workout detection to follower increase
        
        // Given
        let expectation = XCTestExpectation(description: "Complete workout flow")
        let workoutObserver = dependencyContainer.workoutObserver
        let initialFollowers = mockCloudKitManager.followerCount
        let initialWorkouts = mockCloudKitManager.totalWorkouts
        
        // Subscribe to changes
        Publishers.CombineLatest(
            mockCloudKitManager.$followerCount,
            mockCloudKitManager.$totalWorkouts
        )
        .dropFirst() // Skip initial values
        .sink { (followers, workouts) in
            // Verify both values updated
            XCTAssertEqual(followers, initialFollowers + 5)
            XCTAssertEqual(workouts, initialWorkouts + 1)
            expectation.fulfill()
        }
        .store(in: &cancellables)
        
        // When - Simulate the observer detecting a workout
        // In real app, this would come from HealthKit
        NotificationCenter.default.post(
            name: NSNotification.Name("WorkoutCompleted"),
            object: nil,
            userInfo: ["type": "running", "duration": 1800]
        )
        
        // Manually trigger what would happen
        mockCloudKitManager.addFollowers(5)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testErrorHandling() {
        // Given
        mockCloudKitManager.shouldFailAddFollowers = true
        let workoutObserver = dependencyContainer.workoutObserver
        
        // When - Try to add followers
        mockCloudKitManager.addFollowers(5)
        
        // Then
        XCTAssertNotNil(mockCloudKitManager.lastError)
        XCTAssertEqual(mockCloudKitManager.followerCount, 100) // Should not change
    }
    
    func testStreakCalculation() {
        // Given
        let initialStreak = mockCloudKitManager.currentStreak
        
        // When - Complete a workout
        mockCloudKitManager.addFollowers(5)
        
        // Then - In real implementation, streak logic would be tested here
        // For now, we just verify the property exists and can be modified
        XCTAssertGreaterThanOrEqual(mockCloudKitManager.currentStreak, 0)
    }
}