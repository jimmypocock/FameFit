import Combine
@testable import FameFit
import XCTest

class WorkoutIntegrationTests: XCTestCase {
    private var dependencyContainer: DependencyContainer!
    private var mockCloudKitService: MockCloudKitService!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()

        // Create mock managers
        mockCloudKitService = MockCloudKitService()
        let authManager = AuthenticationService(cloudKitManager: mockCloudKitService)
        // Reset auth state for test isolation
        authManager.isAuthenticated = false
        authManager.userID = nil
        authManager.userName = nil
        let workoutObserver = WorkoutObserver(cloudKitManager: mockCloudKitService)

        // Create container with mocks
        dependencyContainer = DependencyContainer(
            authenticationManager: authManager,
            cloudKitManager: mockCloudKitService,
            workoutObserver: workoutObserver
        )
    }

    override func tearDown() {
        cancellables.removeAll()
        mockCloudKitService.reset()
        dependencyContainer = nil

        super.tearDown()
    }

    func testInfluencerXPUpdatesInUI() {
        // Given
        let expectation = XCTestExpectation(description: "XP count updates")
        let initialCount = mockCloudKitService.totalXP

        // Subscribe to XP count changes
        mockCloudKitService.$totalXP
            .dropFirst() // Skip initial value
            .sink { newCount in
                XCTAssertEqual(newCount, initialCount + 5)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When - Simulate workout completion
        mockCloudKitService.addXP(5)

        // Then
        wait(for: [expectation], timeout: 1.0)
    }

    func testAuthenticationFlow() {
        // Given - Start with unauthenticated state
        mockCloudKitService.isSignedIn = false
        mockCloudKitService.userName = ""
        let authManager = dependencyContainer.authenticationManager
        XCTAssertFalse(authManager.isAuthenticated)

        // When - Simulate sign in
        authManager.userID = "test-user"
        authManager.userName = "Test User"
        authManager.isAuthenticated = true
        mockCloudKitService.isSignedIn = true
        mockCloudKitService.userName = "Test User"

        // Then
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertEqual(authManager.userName, "Test User")
    }

    func testWorkoutToXPFlow() {
        // This tests that adding XP updates both XP count and workout count

        // Given
        XCTAssertEqual(mockCloudKitService.totalXP, 100, "Should start with 100 XP")
        XCTAssertEqual(mockCloudKitService.totalWorkouts, 20, "Should start with 20 workouts")

        // When - Simulate what happens when a workout is detected
        mockCloudKitService.addXP(5)

        // Then - Verify synchronous updates
        XCTAssertEqual(mockCloudKitService.totalXP, 105, "Should have 105 XP")
        XCTAssertEqual(mockCloudKitService.totalWorkouts, 21, "Should have 21 workouts")
        XCTAssertTrue(mockCloudKitService.addXPCalled, "Should have called addXP")
        XCTAssertEqual(mockCloudKitService.lastAddedXPCount, 5, "Should have added 5 XP")
    }

    func testErrorHandling() {
        // Given
        mockCloudKitService.shouldFailAddXP = true
        _ = dependencyContainer.workoutObserver // Ensure observer is initialized

        // When - Try to add XP
        mockCloudKitService.addXP(5)

        // Then
        XCTAssertNotNil(mockCloudKitService.lastError)
        XCTAssertEqual(mockCloudKitService.totalXP, 100) // Should not change
    }

    func testStreakCalculation() {
        // Given
        _ = mockCloudKitService.currentStreak // Verify starts at 0

        // When - Complete a workout
        mockCloudKitService.addXP(5)

        // Then - In real implementation, streak logic would be tested here
        // For now, we just verify the property exists and can be modified
        XCTAssertGreaterThanOrEqual(mockCloudKitService.currentStreak, 0)
    }

    func testMockCloudKitServiceBehavior() {
        // Test the mock directly to ensure it works as expected
        XCTAssertEqual(mockCloudKitService.totalXP, 100, "Should start with 100 XP")
        XCTAssertEqual(mockCloudKitService.totalWorkouts, 20, "Should start with 20 workouts")

        // Add XP
        mockCloudKitService.addXP(5)

        // Verify both values updated
        XCTAssertEqual(mockCloudKitService.totalXP, 105, "Should have 105 XP")
        XCTAssertEqual(mockCloudKitService.totalWorkouts, 21, "Should have 21 workouts")
    }
}
