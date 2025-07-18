//
//  MainViewModeling.swift
//  FameFit
//
//  Protocol for MainView business logic separation
//

import SwiftUI
import Foundation

/// Protocol for MainView view model that handles business logic and data formatting
protocol MainViewModeling: ObservableObject {
    // MARK: - User Data
    var userName: String { get }
    var followerCount: Int { get }
    var followerTitle: String { get }
    var totalWorkouts: Int { get }
    var currentStreak: Int { get }
    
    // MARK: - Date Information
    var joinDate: Date? { get }
    var lastWorkoutDate: Date? { get }
    var daysAsMember: Int { get }
    
    // MARK: - Notification State
    var hasUnreadNotifications: Bool { get }
    var unreadNotificationCount: Int { get }
    
    // MARK: - Actions
    func refreshData()
    func signOut()
    func markNotificationsAsRead()
}