import XCTest
import HealthKit
@testable import FameFit

// Simple test cases for WorkoutSyncManager focusing on key behaviors
class WorkoutSyncManagerTests: XCTestCase {
    private var sut: WorkoutSyncManager!
    private var mockCloudKitManager: MockCloudKitManager!
    private var mockHealthKitService: MockHealthKitService!
    private var mockNotificationStore: MockNotificationStore!
    
    override func setUp() {
        super.setUp()
        
        // Clear UserDefaults for sync anchor
        UserDefaults.standard.removeObject(forKey: "FameFitWorkoutSyncAnchor")
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.appInstallDate)
        UserDefaults.standard.removeObject(forKey: NotificationItem.storageKey)
        
        mockCloudKitManager = MockCloudKitManager()
        mockHealthKitService = MockHealthKitService()
        mockNotificationStore = MockNotificationStore()
        
        sut = WorkoutSyncManager(
            cloudKitManager: mockCloudKitManager,
            healthKitService: mockHealthKitService
        )
        sut.notificationStore = mockNotificationStore
    }
    
    override func tearDown() {
        sut.stopSync()
        sut = nil
        mockCloudKitManager = nil
        mockHealthKitService = nil
        mockNotificationStore = nil
        
        UserDefaults.standard.removeObject(forKey: "FameFitWorkoutSyncAnchor")
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.appInstallDate)
        UserDefaults.standard.removeObject(forKey: NotificationItem.storageKey)
        
        super.tearDown()
    }
    
    func testStartReliableSync_WhenHealthKitNotAvailable_SetsError() {
        // Given
        mockHealthKitService.isHealthDataAvailable = false
        
        // When
        sut.startReliableSync()
        
        // Wait for async dispatch
        let expectation = XCTestExpectation(description: "Error set")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(sut.syncError, .healthKitNotAvailable)
    }
    
    func testStartReliableSync_WhenHealthKitAvailable_NoError() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        
        // When
        sut.startReliableSync()
        
        // Then
        // Note: We can't fully test the anchored query behavior because WorkoutSyncManager
        // uses HKHealthStore directly. In a future refactor, we could make it use
        // the HealthKitService protocol for better testability.
        XCTAssertNil(sut.syncError)
    }
    
    func testInitialState() {
        // Then
        XCTAssertFalse(sut.isSyncing)
        XCTAssertNil(sut.lastSyncDate)
        XCTAssertNil(sut.syncError)
    }
    
    // The following tests would require refactoring WorkoutSyncManager to use
    // HealthKitService for anchored queries instead of direct HKHealthStore usage.
    // For now, we'll test what we can with the current architecture.
    
    func testStopSync() {
        // Given
        sut.startReliableSync()
        
        // When
        sut.stopSync()
        
        // Then - Should not crash and should clear any active queries
        XCTAssertNil(sut.syncError)
    }
    
    func testStartReliableSync_WhenHealthKitAvailable_StartsQuery() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        
        // When
        sut.startReliableSync()
        
        // Then
        XCTAssertTrue(mockHealthKitService.anchoredQueryStarted)
        XCTAssertNil(sut.syncError)
    }
    
    func testProcessWorkouts_AddsFollowersForEachWorkout() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        // Set app install date to 1 day ago so test workouts aren't filtered out
        UserDefaults.standard.set(Date().addingTimeInterval(-24 * 3600), forKey: UserDefaultsKeys.appInstallDate)
        let workouts = TestWorkoutBuilder.createMultipleWorkouts(count: 3)
        
        // When - Simulate incremental update
        sut.startReliableSync()
        mockHealthKitService.simulateIncrementalAnchoredQueryResults(workouts: workouts)
        
        // Wait for async processing
        let expectation = XCTestExpectation(description: "Process workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(mockCloudKitManager.addFollowersCalls.count, 3)
        XCTAssertTrue(mockCloudKitManager.addFollowersCalls.allSatisfy { $0.count == 5 })
    }
    
    func testProcessWorkouts_CreatesNotificationsForEachWorkout() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        // Set app install date to 1 day ago so test workouts aren't filtered out
        UserDefaults.standard.set(Date().addingTimeInterval(-24 * 3600), forKey: UserDefaultsKeys.appInstallDate)
        let workouts = TestWorkoutBuilder.createMultipleWorkouts(count: 2)
        
        // When - Simulate incremental update
        sut.startReliableSync()
        mockHealthKitService.simulateIncrementalAnchoredQueryResults(workouts: workouts)
        
        // Wait for async processing
        let expectation = XCTestExpectation(description: "Create notifications")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(mockNotificationStore.notifications.count, 2)
        XCTAssertTrue(mockNotificationStore.notifications.allSatisfy { $0.followersEarned == 5 })
    }
    
    func testProcessWorkouts_SkipsPreInstallWorkouts() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        
        // Set app install date to now
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.appInstallDate)
        
        // Create workouts - one before install, one after
        let oldWorkout = TestWorkoutBuilder.createWorkout(
            type: .running,
            startDate: Date().addingTimeInterval(-86_400), // 1 day ago
            endDate: Date().addingTimeInterval(-85_000)
        )
        let newWorkout = TestWorkoutBuilder.createWorkout(
            type: .running,
            startDate: Date().addingTimeInterval(100),
            endDate: Date().addingTimeInterval(1_000)
        )
        
        // When
        sut.startReliableSync()
        mockHealthKitService.simulateAnchoredQueryResults(workouts: [oldWorkout, newWorkout])
        
        // Wait for async processing
        let expectation = XCTestExpectation(description: "Process workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Only the new workout should be processed
        XCTAssertEqual(mockCloudKitManager.addFollowersCalls.count, 1)
        XCTAssertEqual(mockNotificationStore.notifications.count, 1)
    }
    
    func testProcessWorkouts_SkipsInvalidWorkouts() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        // Set app install date to 1 day ago so test workouts aren't filtered out
        UserDefaults.standard.set(Date().addingTimeInterval(-24 * 3600), forKey: UserDefaultsKeys.appInstallDate)
        
        // Create invalid workout (duration = 0)
        let invalidWorkout = TestWorkoutBuilder.createWorkout(
            type: .running,
            startDate: Date(),
            endDate: Date() // Same as start date
        )
        let validWorkout = TestWorkoutBuilder.createRunWorkout()
        
        // When - Simulate incremental update
        sut.startReliableSync()
        mockHealthKitService.simulateIncrementalAnchoredQueryResults(workouts: [invalidWorkout, validWorkout])
        
        // Wait for async processing
        let expectation = XCTestExpectation(description: "Process workouts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Only valid workout should be processed
        XCTAssertEqual(mockCloudKitManager.addFollowersCalls.count, 1)
        XCTAssertEqual(mockNotificationStore.notifications.count, 1)
    }
    
    func testInitialSync_DoesNotSendNotifications() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        let workouts = TestWorkoutBuilder.createMultipleWorkouts(count: 5)
        
        // When - Simulate initial sync
        sut.startReliableSync()
        mockHealthKitService.simulateInitialAnchoredQueryResults(workouts: workouts)
        
        // Wait for async processing
        let expectation = XCTestExpectation(description: "Initial sync")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Should not add followers or create notifications during initial sync
        XCTAssertEqual(mockCloudKitManager.addFollowersCalls.count, 0)
        XCTAssertEqual(mockNotificationStore.notifications.count, 0)
    }
    
    func testIncrementalSync_SendsNotifications() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        // Set app install date to 1 day ago so test workouts aren't filtered out
        UserDefaults.standard.set(Date().addingTimeInterval(-24 * 3600), forKey: UserDefaultsKeys.appInstallDate)
        let workouts = TestWorkoutBuilder.createMultipleWorkouts(count: 2)
        
        // When - Simulate incremental update
        sut.startReliableSync()
        mockHealthKitService.simulateIncrementalAnchoredQueryResults(workouts: workouts)
        
        // Wait for async processing
        let expectation = XCTestExpectation(description: "Incremental sync")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then - Should add followers and create notifications
        XCTAssertEqual(mockCloudKitManager.addFollowersCalls.count, 2)
        XCTAssertEqual(mockNotificationStore.notifications.count, 2)
    }
    
    func testNotificationContent_ContainsCorrectData() {
        // Given
        mockHealthKitService.isHealthDataAvailable = true
        // Set app install date to 1 day ago so test workouts aren't filtered out
        UserDefaults.standard.set(Date().addingTimeInterval(-24 * 3600), forKey: UserDefaultsKeys.appInstallDate)
        let workout = TestWorkoutBuilder.createRunWorkout(
            duration: 1_800, // 30 minutes
            calories: 250
        )
        
        // When - Simulate incremental update
        sut.startReliableSync()
        mockHealthKitService.simulateIncrementalAnchoredQueryResults(workouts: [workout])
        
        // Wait for async processing
        let expectation = XCTestExpectation(description: "Notification content")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(mockNotificationStore.notifications.count, 1)
        let notification = mockNotificationStore.notifications.first!
        
        XCTAssertEqual(notification.workoutDuration, 30) // minutes
        XCTAssertEqual(notification.calories, 250)
        XCTAssertEqual(notification.followersEarned, 5)
        XCTAssertTrue(notification.body.contains("5 new followers"))
    }
}
