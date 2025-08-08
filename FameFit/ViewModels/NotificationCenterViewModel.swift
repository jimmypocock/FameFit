//
//  NotificationCenterViewModel.swift
//  FameFit
//
//  View model for managing notification center state and interactions
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationCenterViewModel: ObservableObject {
    @Published var notifications: [FameFitNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    @Published var error: String?

    private var notificationStore: (any NotificationStoring)?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    func configure(notificationStore: any NotificationStoring) {
        self.notificationStore = notificationStore

        // Subscribe to notification updates
        notificationStore.notificationsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notifications in
                self?.notifications = notifications
            }
            .store(in: &cancellables)

        notificationStore.unreadCountPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.unreadCount = count
            }
            .store(in: &cancellables)

        // Load initial data
        loadNotifications()
    }

    // MARK: - Data Loading

    func loadNotifications() {
        isLoading = true
        notificationStore?.loadNotifications()
        isLoading = false
    }

    func refreshNotifications() async {
        isLoading = true
        notificationStore?.loadNotifications()
        isLoading = false
    }

    // MARK: - Filtering

    func filteredNotifications(for tab: Int) -> [FameFitNotification] {
        switch tab {
        case 1: // Unread
            notifications.filter { !$0.isRead }
        case 2: // Social
            notifications.filter { notification in
                switch notification.type {
                case .newFollower, .followRequest, .followAccepted, .workoutKudos, .workoutComment,
                     .challengeInvite, .challengeCompleted, .mentioned, .leaderboardChange:
                    true
                default:
                    false
                }
            }
        case 3: // Workouts
            notifications.filter { notification in
                switch notification.type {
                case .workoutCompleted, .unlockAchieved, .levelUp, .xpMilestone, .streakMaintained, .streakAtRisk:
                    true
                default:
                    false
                }
            }
        default: // All
            notifications
        }
    }

    // MARK: - Actions

    func markAsRead(_ id: String) {
        notificationStore?.markAsRead(id)
    }

    func markAllAsRead() {
        notificationStore?.markAllAsRead()
    }

    func clearAllNotifications() {
        notificationStore?.clearAllNotifications()
    }

    func deleteFameFitNotification(_ id: String) {
        notificationStore?.deleteFameFitNotification(id)
    }

    // MARK: - Interaction Handling

    func handleNotificationTap(_ notification: FameFitNotification) {
        // Mark as read if not already
        if !notification.isRead {
            markAsRead(notification.id)
        }

        // Handle type-specific navigation
        switch notification.type {
        case .workoutCompleted, .xpMilestone:
            // Navigate to workout history
            handleWorkoutFameFitNotification(notification)

        case .newFollower, .followRequest:
            // Navigate to followers/social
            handleSocialFameFitNotification(notification)

        case .workoutKudos, .workoutComment:
            // Navigate to specific workout
            handleWorkoutInteractionFameFitNotification(notification)

        case .unlockAchieved, .levelUp:
            // Show achievement details or navigate to profile
            handleAchievementFameFitNotification(notification)

        case .challengeInvite, .challengeCompleted:
            // Navigate to challenges (future)
            handleChallengeFameFitNotification(notification)

        default:
            // Generic notification - no specific action
            break
        }
    }

    func handleNotificationAction(_ notification: FameFitNotification, action: NotificationAction) {
        switch action {
        case .accept:
            handleAcceptAction(notification)
        case .decline:
            handleDeclineAction(notification)
        case .reply:
            handleReplyAction(notification)
        case .view:
            handleViewAction(notification)
        case .kudos:
            handleKudosAction(notification)
        case .dismiss:
            handleDismissAction(notification)
        case .join:
            handleJoinAction(notification)
        case .verify:
            handleVerifyAction(notification)
        }
    }

    // MARK: - Private Notification Handlers

    private func handleWorkoutFameFitNotification(_ notification: FameFitNotification) {
        // TODO: Navigate to workout history or specific workout
        print("Navigate to workout: \(notification.title)")
    }

    private func handleSocialFameFitNotification(_ notification: FameFitNotification) {
        // TODO: Navigate to social/followers view
        if let socialMetadata = notification.socialMetadata {
            print("Navigate to user profile: \(socialMetadata.username)")
        }
    }

    private func handleWorkoutInteractionFameFitNotification(_ notification: FameFitNotification) {
        // TODO: Navigate to specific workout with comments/kudos
        if let workoutMetadata = notification.workoutMetadata {
            print("Navigate to workout details: \(workoutMetadata.workoutID ?? "unknown")")
        }
    }

    private func handleAchievementFameFitNotification(_ notification: FameFitNotification) {
        // TODO: Show achievement modal or navigate to achievements
        if let achievementMetadata = notification.achievementMetadata {
            print("Show achievement: \(achievementMetadata.achievementName)")
        }
    }

    private func handleChallengeFameFitNotification(_ notification: FameFitNotification) {
        // TODO: Navigate to challenges view (future feature)
        if let challengeMetadata = notification.challengeMetadata {
            print("Navigate to challenge: \(challengeMetadata.challengeName)")
        }
    }

    // MARK: - Private Action Handlers

    private func handleAcceptAction(_ notification: FameFitNotification) {
        switch notification.type {
        case .followRequest:
            // TODO: Accept follow request
            print("Accept follow request")
        case .challengeInvite:
            // TODO: Accept challenge
            print("Accept challenge")
        default:
            break
        }
    }

    private func handleDeclineAction(_ notification: FameFitNotification) {
        switch notification.type {
        case .followRequest:
            // TODO: Decline follow request
            print("Decline follow request")
        case .challengeInvite:
            // TODO: Decline challenge
            print("Decline challenge")
        default:
            break
        }
    }

    private func handleReplyAction(_: FameFitNotification) {
        // TODO: Open reply interface
        print("Reply to notification")
    }

    private func handleViewAction(_ notification: FameFitNotification) {
        // Same as tap - navigate to relevant view
        handleNotificationTap(notification)
    }

    private func handleKudosAction(_: FameFitNotification) {
        // TODO: Give kudos to the content (workout, comment, etc.)
        print("Give kudos to content")
    }

    private func handleDismissAction(_ notification: FameFitNotification) {
        // Mark as read and potentially hide
        markAsRead(notification.id)
    }
    
    private func handleJoinAction(_ notification: FameFitNotification) {
        // Handle joining a group workout
        switch notification.type {
        case .groupWorkoutInvite, .groupWorkoutStarting, .groupWorkoutReminder:
            // TODO: Navigate to group workout and join
            print("Join group workout")
        default:
            print("Join action for \(notification.type)")
        }
    }
    
    private func handleVerifyAction(_ notification: FameFitNotification) {
        // Handle manual verification request
        switch notification.type {
        case .workoutVerificationFailed:
            // TODO: Navigate to verification request screen
            print("Request manual verification")
        default:
            print("Verify action for \(notification.type)")
        }
    }
}
