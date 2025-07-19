//
//  MainViewModel.swift
//  FameFit
//
//  View model for MainView implementing MainViewModeling protocol
//

import SwiftUI
import Foundation
import Combine

/// View model that handles MainView business logic and data formatting
class MainViewModel: ObservableObject, MainViewModeling {
    
    // MARK: - Dependencies
    private let authManager: any AuthenticationManaging
    private let cloudKitManager: any CloudKitManaging
    private let notificationStore: any NotificationStoring
    
    // MARK: - Published Properties
    @Published private var _userName: String = ""
    @Published private var _influencerXP: Int = 0
    @Published private var _xpTitle: String = ""
    @Published private var _totalWorkouts: Int = 0
    @Published private var _currentStreak: Int = 0
    @Published private var _joinDate: Date?
    @Published private var _lastWorkoutDate: Date?
    @Published private var _unreadCount: Int = 0
    
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        authManager: any AuthenticationManaging,
        cloudKitManager: any CloudKitManaging,
        notificationStore: any NotificationStoring
    ) {
        self.authManager = authManager
        self.cloudKitManager = cloudKitManager
        self.notificationStore = notificationStore
        
        setupBindings()
    }
    
    // MARK: - Protocol Properties
    var userName: String { _userName }
    var influencerXP: Int { _influencerXP }
    var xpTitle: String { _xpTitle }
    var totalWorkouts: Int { _totalWorkouts }
    var currentStreak: Int { _currentStreak }
    var joinDate: Date? { _joinDate }
    var lastWorkoutDate: Date? { _lastWorkoutDate }
    var hasUnreadNotifications: Bool { _unreadCount > 0 }
    var unreadNotificationCount: Int { _unreadCount }
    
    var daysAsMember: Int {
        guard let joinDate = _joinDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: joinDate, to: Date()).day ?? 0
    }
    
    // MARK: - Protocol Methods
    func refreshData() {
        cloudKitManager.fetchUserRecord()
        refreshFromDependencies()
    }
    
    func signOut() {
        authManager.signOut()
    }
    
    func markNotificationsAsRead() {
        notificationStore.markAllAsRead()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Initialize with current values from protocol-based dependencies
        refreshFromDependencies()
        
        // Set up reactive bindings with protocol publishers
        cloudKitManager.userNamePublisher
            .assign(to: &$_userName)
        
        cloudKitManager.influencerXPPublisher
            .assign(to: &$_influencerXP)
        
        cloudKitManager.totalWorkoutsPublisher
            .assign(to: &$_totalWorkouts)
        
        cloudKitManager.currentStreakPublisher
            .assign(to: &$_currentStreak)
        
        cloudKitManager.joinTimestampPublisher
            .assign(to: &$_joinDate)
        
        cloudKitManager.lastWorkoutTimestampPublisher
            .assign(to: &$_lastWorkoutDate)
        
        cloudKitManager.influencerXPPublisher
            .map { [weak self] _ in
                self?.cloudKitManager.getXPTitle() ?? ""
            }
            .assign(to: &$_xpTitle)
        
        notificationStore.unreadCountPublisher
            .assign(to: &$_unreadCount)
    }
    
    private func refreshFromDependencies() {
        _userName = cloudKitManager.userName
        _influencerXP = cloudKitManager.influencerXP
        _totalWorkouts = cloudKitManager.totalWorkouts
        _currentStreak = cloudKitManager.currentStreak
        _joinDate = cloudKitManager.joinTimestamp
        _lastWorkoutDate = cloudKitManager.lastWorkoutTimestamp
        _xpTitle = cloudKitManager.getXPTitle()
        _unreadCount = notificationStore.unreadCount
    }
}