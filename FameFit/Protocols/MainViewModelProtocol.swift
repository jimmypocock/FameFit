//
//  MainViewModelProtocol.swift
//  FameFit
//
//  Protocol for MainView business logic separation
//

import Foundation
import SwiftUI

/// Protocol for MainView view model that handles business logic and data formatting
protocol MainViewModelProtocol: ObservableObject {
    // MARK: - User Data

    var userName: String { get }
    var totalXP: Int { get }
    var xpTitle: String { get }
    var totalWorkouts: Int { get }
    var currentStreak: Int { get }

    // MARK: - Profile Data

    var userProfile: UserProfile? { get }
    var hasProfile: Bool { get }

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
    func loadUserProfile()
    func refreshUserProfile()
}
