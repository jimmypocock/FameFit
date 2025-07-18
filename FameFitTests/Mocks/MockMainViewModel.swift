//
//  MockMainViewModel.swift
//  FameFitTests
//
//  Mock implementation of MainViewModeling for testing
//

import Foundation
import Combine
@testable import FameFit

/// Mock view model for testing MainView
class MockMainViewModel: MainViewModeling {
    
    // MARK: - Published Properties
    @Published var userName: String = "Test User"
    @Published var followerCount: Int = 42
    @Published var followerTitle: String = "Rising Star"
    @Published var totalWorkouts: Int = 15
    @Published var currentStreak: Int = 3
    @Published var joinDate: Date? = Date().addingTimeInterval(-30 * 24 * 3600) // 30 days ago
    @Published var lastWorkoutDate: Date? = Date().addingTimeInterval(-2 * 3600) // 2 hours ago
    @Published var hasUnreadNotifications: Bool = true
    @Published var unreadNotificationCount: Int = 2
    
    // MARK: - Computed Properties
    var daysAsMember: Int {
        guard let joinDate = joinDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: joinDate, to: Date()).day ?? 0
    }
    
    // MARK: - Method Call Tracking
    var refreshDataCalled = false
    var signOutCalled = false
    var markNotificationsAsReadCalled = false
    
    // MARK: - Test Configuration
    var shouldFailRefresh = false
    var shouldFailSignOut = false
    
    // MARK: - Protocol Methods
    func refreshData() {
        refreshDataCalled = true
        
        if shouldFailRefresh {
            // Simulate failure - no data updates
            return
        }
        
        // Simulate successful data refresh
        followerCount += 1
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
        followerCount = 0
        followerTitle = ""
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
    
    // MARK: - Test Helpers
    func simulateNewWorkout() {
        totalWorkouts += 1
        followerCount += 5
        currentStreak += 1
        lastWorkoutDate = Date()
    }
    
    func simulateNewNotification() {
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
        followerCount = 42
        followerTitle = "Rising Star"
        totalWorkouts = 15
        currentStreak = 3
        joinDate = Date().addingTimeInterval(-30 * 24 * 3600)
        lastWorkoutDate = Date().addingTimeInterval(-2 * 3600)
        hasUnreadNotifications = true
        unreadNotificationCount = 2
    }
}