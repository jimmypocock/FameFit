//
//  MainViewModelReactiveTests.swift
//  FameFitTests
//
//  Tests for reactive updates in MainViewModel using protocol-based publishers
//

import XCTest
import Combine
@testable import FameFit

class MainViewModelReactiveTests: XCTestCase {
    
    var viewModel: MainViewModel!
    var mockAuthManager: MockAuthenticationManager!
    var mockCloudKitManager: MockCloudKitManager!
    var mockNotificationStore: MockNotificationStore!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        mockAuthManager = MockAuthenticationManager()
        mockCloudKitManager = MockCloudKitManager()
        mockNotificationStore = MockNotificationStore()
        cancellables = Set<AnyCancellable>()
        
        viewModel = MainViewModel(
            authManager: mockAuthManager,
            cloudKitManager: mockCloudKitManager,
            notificationStore: mockNotificationStore,
            userProfileService: MockUserProfileService()
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockAuthManager = nil
        mockCloudKitManager = nil
        mockNotificationStore = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - CloudKit Publisher Tests
    
    func testUserNameUpdatesReactively() {
        // Given
        let initialUserName = viewModel.userName
        
        // When
        mockCloudKitManager.userName = "New User Name"
        
        // Allow time for publisher to propagate
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.userName, "New User Name")
        XCTAssertNotEqual(viewModel.userName, initialUserName)
    }
    
    func testInfluencerXPUpdatesReactively() {
        // Given
        let initialCount = viewModel.totalXP
        
        // When
        mockCloudKitManager.totalXP = 250
        
        // Allow time for publisher to propagate
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.totalXP, 250)
        XCTAssertNotEqual(viewModel.totalXP, initialCount)
    }
    
    func testXPTitleUpdatesWithInfluencerXP() {
        // Given
        let initialTitle = viewModel.xpTitle
        XCTAssertEqual(initialTitle, "Micro-Influencer") // 100 XP (from mock init)
        
        // When
        mockCloudKitManager.totalXP = 3000 // Should trigger "Rising Star" title
        
        // Force a manual refresh to ensure the reactive binding picks up the change
        viewModel.refreshData()
        
        // Allow more time for publisher to propagate through reactive chain
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        // Then
        XCTAssertEqual(viewModel.xpTitle, "Rising Star")
        XCTAssertNotEqual(viewModel.xpTitle, initialTitle)
    }
    
    func testTotalWorkoutsUpdatesReactively() {
        // Given
        let initialCount = viewModel.totalWorkouts
        
        // When
        mockCloudKitManager.totalWorkouts = 50
        
        // Allow time for publisher to propagate
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.totalWorkouts, 50)
        XCTAssertNotEqual(viewModel.totalWorkouts, initialCount)
    }
    
    func testCurrentStreakUpdatesReactively() {
        // Given
        let initialStreak = viewModel.currentStreak
        
        // When
        mockCloudKitManager.currentStreak = 15
        
        // Allow time for publisher to propagate
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.currentStreak, 15)
        XCTAssertNotEqual(viewModel.currentStreak, initialStreak)
    }
    
    func testJoinDateUpdatesReactively() {
        // Given
        let newJoinDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        
        // When
        mockCloudKitManager.joinTimestamp = newJoinDate
        
        // Allow time for publisher to propagate
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertNotNil(viewModel.joinDate)
        XCTAssertEqual(viewModel.joinDate?.timeIntervalSince1970 ?? 0, newJoinDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    func testLastWorkoutDateUpdatesReactively() {
        // Given
        let newWorkoutDate = Date().addingTimeInterval(-2 * 60 * 60) // 2 hours ago
        
        // When
        mockCloudKitManager.lastWorkoutTimestamp = newWorkoutDate
        
        // Allow time for publisher to propagate
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertNotNil(viewModel.lastWorkoutDate)
        XCTAssertEqual(viewModel.lastWorkoutDate?.timeIntervalSince1970 ?? 0, newWorkoutDate.timeIntervalSince1970, accuracy: 1.0)
    }
    
    // MARK: - Notification Store Publisher Tests
    
    func testUnreadCountUpdatesReactively() {
        // Given
        let initialCount = viewModel.unreadNotificationCount
        
        // When
        mockNotificationStore.unreadCount = 5
        
        // Allow time for publisher to propagate
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.unreadNotificationCount, 5)
        XCTAssertTrue(viewModel.hasUnreadNotifications)
        XCTAssertNotEqual(viewModel.unreadNotificationCount, initialCount)
    }
    
    func testHasUnreadNotificationsUpdatesReactively() {
        // Given
        XCTAssertFalse(viewModel.hasUnreadNotifications)
        
        // When - Set unread count to make hasUnread = true
        mockNotificationStore.unreadCount = 3
        
        // Allow time for publisher to propagate
        let expectation1 = XCTestExpectation(description: "First update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 1.0)
        
        // Then
        XCTAssertTrue(viewModel.hasUnreadNotifications)
        
        // When - Set unread count to 0 to make hasUnread = false
        mockNotificationStore.unreadCount = 0
        
        let expectation2 = XCTestExpectation(description: "Second update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 1.0)
        
        // Then
        XCTAssertFalse(viewModel.hasUnreadNotifications)
    }
    
    // MARK: - Multiple Updates Test
    
    func testMultiplePropertiesUpdateSimultaneously() {
        // Given
        let initialUserName = viewModel.userName
        let initialInfluencerXP = viewModel.totalXP
        let initialTotalWorkouts = viewModel.totalWorkouts
        
        // When - Simulate a workout being recorded
        mockCloudKitManager.userName = "Active User"
        mockCloudKitManager.totalXP = 150
        mockCloudKitManager.totalWorkouts = 25
        
        // Allow time for publishers to propagate
        let expectation = XCTestExpectation(description: "Publishers update")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.userName, "Active User")
        XCTAssertEqual(viewModel.totalXP, 150)
        XCTAssertEqual(viewModel.totalWorkouts, 25)
        XCTAssertNotEqual(viewModel.userName, initialUserName)
        XCTAssertNotEqual(viewModel.totalXP, initialInfluencerXP)
        XCTAssertNotEqual(viewModel.totalWorkouts, initialTotalWorkouts)
    }
    
    // MARK: - Computed Property Tests
    
    func testDaysAsMemberUpdatesWhenJoinDateChanges() {
        // Given
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let initialDaysAsMember = viewModel.daysAsMember
        
        // When
        mockCloudKitManager.joinTimestamp = thirtyDaysAgo
        
        // Allow time for publisher to propagate
        let expectation = XCTestExpectation(description: "Publisher updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertEqual(viewModel.daysAsMember, 30)
        XCTAssertNotEqual(viewModel.daysAsMember, initialDaysAsMember)
    }
}