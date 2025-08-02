//
//  MockMainViewModel.swift
//  FameFitTests
//
//  Mock implementation of MainViewModeling for testing
//

import Combine
@testable import FameFit
import Foundation

/// Mock view model for testing MainView
class MockMainViewModel: MainViewModeling {
    // MARK: - Published Properties

    @Published var userName: String = "Test User"
    @Published var totalXP: Int = 42
    @Published var xpTitle: String = "Rising Star"
    @Published var totalWorkouts: Int = 15
    @Published var currentStreak: Int = 3
    @Published var joinDate: Date? = Date().addingTimeInterval(-30 * 24 * 3_600) // 30 days ago
    @Published var lastWorkoutDate: Date? = Date().addingTimeInterval(-2 * 3_600) // 2 hours ago
    @Published var hasUnreadNotifications: Bool = true
    @Published var unreadNotificationCount: Int = 2
    @Published var userProfile: UserProfile? = UserProfile.mockProfile

    var hasProfile: Bool {
        userProfile != nil
    }

    // MARK: - Computed Properties

    var daysAsMember: Int {
        guard let joinDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: joinDate, to: Date()).day ?? 0
    }

    // MARK: - Method Call Tracking

    var refreshDataCalled = false
    var signOutCalled = false
    var markNotificationsAsReadCalled = false
    var loadUserProfileCalled = false

    // MARK: - Test Configuration

    var shouldFailRefresh = false
    var shouldFailSignOut = false
    var shouldFailLoadProfile = false

    // MARK: - Protocol Methods

    func refreshData() {
        refreshDataCalled = true

        if shouldFailRefresh {
            // Simulate failure - no data updates
            return
        }

        // Simulate successful data refresh
        totalXP += 1
        totalWorkouts += 1
    }

    func signOut() {
        signOutCalled = true

        if shouldFailSignOut {
            // Simulate failure
            return
        }

        // Simulate successful sign out - reset data
        userName = ""
        totalXP = 0
        xpTitle = ""
        totalWorkouts = 0
        currentStreak = 0
        joinDate = nil
        lastWorkoutDate = nil
    }

    func markNotificationsAsRead() {
        markNotificationsAsReadCalled = true

        // Simulate marking as read
        hasUnreadNotifications = false
        unreadNotificationCount = 0
    }

    func loadUserProfile() {
        loadUserProfileCalled = true

        if shouldFailLoadProfile {
            // Simulate no profile
            userProfile = nil
            return
        }

        // Profile is already set in initialization
    }
    
    func refreshUserProfile() {
        loadUserProfileCalled = true

        if shouldFailLoadProfile {
            // Simulate no profile
            userProfile = nil
            return
        }

        // Profile is already set in initialization
    }

    // MARK: - Test Helpers

    func simulateNewWorkout() {
        totalWorkouts += 1
        totalXP += 5
        currentStreak += 1
        lastWorkoutDate = Date()
    }

    func simulateNewFameFitNotification() {
        hasUnreadNotifications = true
        unreadNotificationCount += 1
    }

    func reset() {
        refreshDataCalled = false
        signOutCalled = false
        markNotificationsAsReadCalled = false
        shouldFailRefresh = false
        shouldFailSignOut = false

        userName = "Test User"
        totalXP = 42
        xpTitle = "Rising Star"
        totalWorkouts = 15
        currentStreak = 3
        joinDate = Date().addingTimeInterval(-30 * 24 * 3_600)
        lastWorkoutDate = Date().addingTimeInterval(-2 * 3_600)
        hasUnreadNotifications = true
        unreadNotificationCount = 2
    }
}
