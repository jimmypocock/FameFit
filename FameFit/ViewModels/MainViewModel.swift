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
class MainViewModel: ObservableObject, MainViewModeling {
    // MARK: - Dependencies

    private let authManager: any AuthenticationManaging
    private let cloudKitManager: any CloudKitManaging
    private let notificationStore: any NotificationStoring
    private let userProfileService: any UserProfileServicing
    private let socialFollowingService: any SocialFollowingServicing

    // MARK: - Published Properties

    @Published private var _userName: String = ""
    @Published private var _totalXP: Int = 0
    @Published private var _xpTitle: String = ""
    @Published private var _totalWorkouts: Int = 0
    @Published private var _currentStreak: Int = 0
    @Published private var _creationDate: Date?
    @Published private var _lastWorkoutDate: Date?
    @Published private var _unreadCount: Int = 0
    @Published var userProfile: UserProfile?
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        authManager: any AuthenticationManaging,
        cloudKitManager: any CloudKitManaging,
        notificationStore: any NotificationStoring,
        userProfileService: any UserProfileServicing,
        socialFollowingService: any SocialFollowingServicing
    ) {
        self.authManager = authManager
        self.cloudKitManager = cloudKitManager
        self.notificationStore = notificationStore
        self.userProfileService = userProfileService
        self.socialFollowingService = socialFollowingService

        setupBindings()
    }

    // MARK: - Protocol Properties

    var userName: String { _userName }
    var totalXP: Int { _totalXP }
    var xpTitle: String { _xpTitle }
    var totalWorkouts: Int { _totalWorkouts }
    var currentStreak: Int { _currentStreak }
    var joinDate: Date? { _creationDate }
    var lastWorkoutDate: Date? { _lastWorkoutDate }
    var hasUnreadNotifications: Bool { _unreadCount > 0 }
    var unreadNotificationCount: Int { _unreadCount }

    var daysAsMember: Int {
        guard let joinDate = _creationDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: joinDate, to: Date()).day ?? 0
    }

    var hasProfile: Bool {
        userProfile != nil
    }

    // MARK: - Protocol Methods

    func refreshData() {
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
        authManager.signOut()
    }

    func markNotificationsAsRead() {
        notificationStore.markAllAsRead()
    }

    func loadUserProfile() {
        Task {
            // First ensure CloudKit is ready
            await ensureCloudKitReady()

            do {
                let profile = try await userProfileService.fetchCurrentUserProfile()
                await MainActor.run {
                    self.userProfile = profile
                    // Send user data to Watch
                    WatchConnectivityManager.shared.sendUserData(
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
        Task {
            // First ensure CloudKit is ready
            await ensureCloudKitReady()

            do {
                let profile = try await userProfileService.fetchCurrentUserProfileFresh()
                await MainActor.run {
                    self.userProfile = profile
                    // Send updated user data to Watch
                    WatchConnectivityManager.shared.sendUserData(
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
        guard let userID = userProfile?.id ?? cloudKitManager.currentUserID else { return }

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
        cloudKitManager.userNamePublisher
            .assign(to: &$_userName)

        cloudKitManager.totalXPPublisher
            .assign(to: &$_totalXP)

        cloudKitManager.totalWorkoutsPublisher
            .assign(to: &$_totalWorkouts)

        cloudKitManager.currentStreakPublisher
            .assign(to: &$_currentStreak)

        cloudKitManager.joinTimestampPublisher
            .assign(to: &$_creationDate)

        cloudKitManager.lastWorkoutTimestampPublisher
            .assign(to: &$_lastWorkoutDate)

        cloudKitManager.totalXPPublisher
            .map { [weak self] _ in
                self?.cloudKitManager.getXPTitle() ?? ""
            }
            .assign(to: &$_xpTitle)

        notificationStore.unreadCountPublisher
            .assign(to: &$_unreadCount)
    }

    private func refreshFromDependencies() {
        _userName = cloudKitManager.userName
        _totalXP = cloudKitManager.totalXP
        _totalWorkouts = cloudKitManager.totalWorkouts
        _currentStreak = cloudKitManager.currentStreak
        _creationDate = cloudKitManager.joinTimestamp
        _lastWorkoutDate = cloudKitManager.lastWorkoutTimestamp
        _xpTitle = cloudKitManager.getXPTitle()
        _unreadCount = notificationStore.unreadCount
    }
}
