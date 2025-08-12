//
//  MainViewModel.swift
//  FameFit
//
//  View model for MainView implementing MainViewModeling protocol
//

import Combine
import Foundation
import SwiftUI

/// View model that handles MainView business logic and data formatting
class MainViewModel: ObservableObject, MainViewModelProtocol {
    // MARK: - Dependencies

    private var authManager: (any AuthenticationProtocol)?
    private var cloudKitManager: (any CloudKitProtocol)?
    private var notificationStore: (any NotificationStoringProtocol)?
    private var userProfileService: (any UserProfileProtocol)?
    private var socialFollowingService: (any SocialFollowingProtocol)?
    private var watchConnectivityManager: (any WatchConnectivityProtocol)?

    // MARK: - Published Properties

    @Published private var _username: String = ""
    @Published private var _totalXP: Int = 0
    @Published private var _xpTitle: String = ""
    @Published private var _totalWorkouts: Int = 0
    @Published private var _currentStreak: Int = 0
    @Published private var _lastWorkoutDate: Date?
    @Published private var _unreadCount: Int = 0
    @Published var userProfile: UserProfile?
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false

    // MARK: - Initialization

    /// Default initializer for StateObject creation
    init() {
        // Dependencies will be configured later via configure method
    }
    
    /// Legacy initializer for backwards compatibility
    init(
        authManager: any AuthenticationProtocol,
        cloudKitManager: any CloudKitProtocol,
        notificationStore: any NotificationStoringProtocol,
        userProfileService: any UserProfileProtocol,
        socialFollowingService: any SocialFollowingProtocol,
        watchConnectivityManager: any WatchConnectivityProtocol
    ) {
        self.authManager = authManager
        self.cloudKitManager = cloudKitManager
        self.notificationStore = notificationStore
        self.userProfileService = userProfileService
        self.socialFollowingService = socialFollowingService
        self.watchConnectivityManager = watchConnectivityManager

        setupBindings()
    }
    
    /// Configure the view model with dependencies
    func configure(
        authManager: any AuthenticationProtocol,
        cloudKitManager: any CloudKitProtocol,
        notificationStore: any NotificationStoringProtocol,
        userProfileService: any UserProfileProtocol,
        socialFollowingService: any SocialFollowingProtocol,
        watchConnectivityManager: any WatchConnectivityProtocol
    ) {
        guard !isConfigured else { return } // Only configure once
        
        self.authManager = authManager
        self.cloudKitManager = cloudKitManager
        self.notificationStore = notificationStore
        self.userProfileService = userProfileService
        self.socialFollowingService = socialFollowingService
        self.watchConnectivityManager = watchConnectivityManager
        
        isConfigured = true
        setupBindings()
    }

    // MARK: - Protocol Properties

    var username: String { _username }
    var totalXP: Int { _totalXP }
    var xpTitle: String { _xpTitle }
    var totalWorkouts: Int { _totalWorkouts }
    var currentStreak: Int { _currentStreak }
    var joinDate: Date? { userProfile?.creationDate }
    var lastWorkoutDate: Date? { _lastWorkoutDate }
    var hasUnreadNotifications: Bool { _unreadCount > 0 }
    var unreadNotificationCount: Int { _unreadCount }

    var daysAsMember: Int {
        guard let joinDate = userProfile?.creationDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: joinDate, to: Date()).day ?? 0
    }

    var hasProfile: Bool {
        userProfile != nil
    }

    // MARK: - Protocol Methods

    func refreshData() {
        guard let cloudKitManager = cloudKitManager else { return }
        
        cloudKitManager.fetchUserRecord()
        refreshFromDependencies()
        
        // Check if stats recalculation is needed
        Task {
            do {
                try await cloudKitManager.recalculateStatsIfNeeded()
            } catch {
                print("Failed to recalculate stats: \(error)")
            }
        }
    }

    func signOut() {
        authManager?.signOut()
    }

    func markNotificationsAsRead() {
        notificationStore?.markAllAsRead()
    }

    func loadUserProfile() {
        guard let userProfileService = userProfileService,
              let watchConnectivityManager = watchConnectivityManager else { return }
        
        Task {
            // First ensure CloudKit is ready
            await ensureCloudKitReady()

            do {
                let profile = try await userProfileService.fetchCurrentUserProfile()
                await MainActor.run {
                    self.userProfile = profile
                    // Send user data to Watch
                    watchConnectivityManager.sendUserData(
                        username: profile.username,
                        totalXP: profile.totalXP
                    )
                }
            } catch {
                // Profile doesn't exist yet, that's ok
                await MainActor.run {
                    self.userProfile = nil
                }
            }
        }
    }
    
    func refreshUserProfile() {
        guard let userProfileService = userProfileService,
              let watchConnectivityManager = watchConnectivityManager else { return }
        
        Task {
            // First ensure CloudKit is ready
            await ensureCloudKitReady()

            do {
                let profile = try await userProfileService.fetchCurrentUserProfileFresh()
                await MainActor.run {
                    self.userProfile = profile
                    // Send updated user data to Watch
                    watchConnectivityManager.sendUserData(
                        username: profile.username,
                        totalXP: profile.totalXP
                    )
                }
            } catch {
                // Profile doesn't exist yet, that's ok
                await MainActor.run {
                    self.userProfile = nil
                }
            }
        }
    }

    private func ensureCloudKitReady() async {
        // Wait for CloudKit to be properly initialized
        var attempts = 0
        let maxAttempts = 30 // 3 seconds max wait

        guard let cloudKitManager = cloudKitManager else { return }
        
        while !cloudKitManager.isAvailable || cloudKitManager.currentUserID == nil {
            if attempts >= maxAttempts {
                print("⚠️ CloudKit initialization timeout after 3 seconds")
                break
            }

            // Trigger CloudKit initialization if needed
            if attempts == 0 {
                cloudKitManager.checkAccountStatus()
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            attempts += 1
        }
    }

    func loadFollowerCounts() {
        guard let socialFollowingService = socialFollowingService,
              let userID = userProfile?.id ?? cloudKitManager?.currentUserID else { return }

        Task {
            do {
                // Load counts in parallel
                async let followers = socialFollowingService.getFollowerCount(for: userID)
                async let following = socialFollowingService.getFollowingCount(for: userID)

                let followerCount = try await followers
                let followingCount = try await following

                await MainActor.run {
                    self.followerCount = followerCount
                    self.followingCount = followingCount
                }
            } catch {
                // Silently fail, counts are not critical
                print("Failed to load follower counts: \(error)")
            }
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Initialize with current values from protocol-based dependencies
        refreshFromDependencies()

        // Set up reactive bindings with protocol publishers
        cloudKitManager?.usernamePublisher
            .assign(to: &$_username)

        cloudKitManager?.totalXPPublisher
            .assign(to: &$_totalXP)

        cloudKitManager?.totalWorkoutsPublisher
            .assign(to: &$_totalWorkouts)

        cloudKitManager?.currentStreakPublisher
            .assign(to: &$_currentStreak)

        cloudKitManager?.lastWorkoutTimestampPublisher
            .assign(to: &$_lastWorkoutDate)

        cloudKitManager?.totalXPPublisher
            .map { [weak self] _ in
                self?.cloudKitManager?.getXPTitle() ?? ""
            }
            .assign(to: &$_xpTitle)

        notificationStore?.unreadCountPublisher
            .assign(to: &$_unreadCount)
    }

    private func refreshFromDependencies() {
        _username = cloudKitManager?.username ?? ""
        _totalXP = cloudKitManager?.totalXP ?? 0
        _totalWorkouts = cloudKitManager?.totalWorkouts ?? 0
        _currentStreak = cloudKitManager?.currentStreak ?? 0
        _lastWorkoutDate = cloudKitManager?.lastWorkoutTimestamp
        _xpTitle = cloudKitManager?.getXPTitle() ?? ""
        _unreadCount = notificationStore?.unreadCount ?? 0
    }
}
