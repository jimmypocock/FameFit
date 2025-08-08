//
//  NotificationRowView.swift
//  FameFit
//
//  Individual notification row component for the notification center
//

import SwiftUI

struct NotificationRowView: View {
    let notification: FameFitNotification
    let onTap: () -> Void
    let onAction: (NotificationAction) -> Void

    @State private var showingActions = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Notification icon and unread indicator
                ZStack {
                    Circle()
                        .fill(notification.isRead ? Color.gray.opacity(0.2) : iconColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: iconName)
                        .font(.system(size: 20))
                        .foregroundColor(notification.isRead ? .gray : iconColor)

                    // Unread indicator
                    if !notification.isRead {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red, Color.red.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 10, height: 10)
                            .shadow(color: .red.opacity(0.3), radius: 1, x: 0, y: 0.5)
                            .offset(x: 18, y: -18)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title and timestamp
                    HStack(alignment: .top) {
                        Text(notification.title)
                            .font(.body)
                            .fontWeight(notification.isRead ? .regular : .semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Text(timeAgoString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Body text
                    Text(notification.body)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(notification.isRead ? 2 : 3)
                        .animation(.easeInOut(duration: 0.2), value: notification.isRead)

                    // Type-specific content
                    typeSpecificContent
                        .padding(.top, 4)

                    // Actions
                    if !notification.actions.isEmpty {
                        actionButtons
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(notification.isRead ? Color(.systemBackground) : Color.blue.opacity(0.06))
                    .shadow(
                        color: notification.isRead ? .clear : .blue.opacity(0.1),
                        radius: notification.isRead ? 0 : 2,
                        x: 0,
                        y: notification.isRead ? 0 : 1
                    )
                    .animation(.easeInOut(duration: 0.25), value: notification.isRead)
            )
            .overlay(
                // Subtle border for unread notifications
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        notification.isRead ? Color.clear : Color.blue.opacity(0.15),
                        lineWidth: notification.isRead ? 0 : 1
                    )
                    .animation(.easeInOut(duration: 0.25), value: notification.isRead)
            )
            .scaleEffect(notification.isRead ? 1.0 : 1.01)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: notification.isRead)
        }
        .buttonStyle(.plain)
        .contextMenu {
            contextMenuItems
        }
    }

    // MARK: - Computed Properties

    private var iconName: String {
        switch notification.type {
        case .workoutCompleted:
            "figure.run"
        case .workoutShared:
            "square.and.arrow.up"
        case .unlockAchieved:
            "trophy.fill"
        case .levelUp:
            "arrow.up.circle.fill"
        case .newFollower:
            "person.badge.plus"
        case .followRequest:
            "person.crop.circle.badge.questionmark"
        case .workoutKudos:
            "heart.fill"
        case .workoutComment:
            "bubble.left.fill"
        case .xpMilestone:
            "star.circle.fill"
        case .challengeInvite:
            "flag.fill"
        case .challengeStarted:
            "flag.fill"
        case .challengeCompleted:
            "flag.checkered"
        case .streakMaintained:
            "flame.fill"
        case .streakAtRisk:
            "exclamationmark.triangle.fill"
        case .securityAlert:
            "exclamationmark.triangle.fill"
        case .followAccepted:
            "person.check.fill"
        case .mentioned:
            "at"
        case .leaderboardChange:
            "chart.bar.fill"
        case .privacyUpdate:
            "lock.fill"
        case .featureAnnouncement:
            "sparkles"
        case .maintenanceNotice:
            "gear"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case .workoutCompleted, .workoutShared, .xpMilestone:
            .blue
        case .unlockAchieved:
            .yellow
        case .levelUp:
            .purple
        case .newFollower, .followRequest, .followAccepted:
            .green
        case .workoutKudos:
            .red
        case .workoutComment, .mentioned:
            .orange
        case .challengeInvite, .challengeStarted, .challengeCompleted:
            .indigo
        case .streakMaintained:
            .orange
        case .streakAtRisk, .securityAlert:
            .red
        case .leaderboardChange:
            .blue
        case .privacyUpdate:
            .gray
        case .featureAnnouncement:
            .purple
        case .maintenanceNotice:
            .gray
        }
    }

    private var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: notification.timestamp, relativeTo: Date())
    }

    @ViewBuilder
    private var typeSpecificContent: some View {
        switch notification.type {
        case .workoutCompleted:
            if let workoutMetadata = notification.workoutMetadata {
                workoutDetails(workoutMetadata)
            }
        case .workoutShared:
            if let workoutMetadata = notification.workoutMetadata {
                workoutDetails(workoutMetadata)
            }
        case .unlockAchieved:
            if let achievementMetadata = notification.achievementMetadata {
                achievementDetails(achievementMetadata)
            }
        case .newFollower, .followRequest, .followAccepted, .workoutKudos, .workoutComment, .mentioned:
            if let socialMetadata = notification.socialMetadata {
                socialDetails(socialMetadata)
            }
        case .xpMilestone, .levelUp, .streakMaintained, .streakAtRisk,
             .challengeInvite, .challengeStarted, .challengeCompleted,
             .leaderboardChange, .securityAlert, .privacyUpdate,
             .featureAnnouncement, .maintenanceNotice:
            EmptyView()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            ForEach(notification.actions, id: \.self) { action in
                Button(action.displayName) {
                    onAction(action)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(actionButtonColor(for: action))
                .foregroundColor(actionButtonTextColor(for: action))
                .cornerRadius(6)
            }
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if !notification.isRead {
            Button(action: { onAction(.dismiss) }) {
                Label("Mark as Read", systemImage: "checkmark.circle")
            }
        }

        Button(action: { onAction(.view) }) {
            Label("View", systemImage: "eye")
        }

        Button(role: .destructive, action: {}) {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Type-Specific Views

    private func workoutDetails(_ metadata: WorkoutNotificationMetadata) -> some View {
        HStack(spacing: 16) {
            if metadata.duration > 0 {
                Label("\(metadata.duration) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if metadata.calories > 0 {
                Label("\(metadata.calories) cal", systemImage: "flame")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if metadata.xpEarned > 0 {
                Label("+\(metadata.xpEarned) XP", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }

            Spacer()
        }
    }

    private func achievementDetails(_ metadata: AchievementNotificationMetadata) -> some View {
        HStack {
            Text(metadata.iconEmoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.achievementName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(metadata.category.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }

    private func socialDetails(_ metadata: SocialNotificationMetadata) -> some View {
        HStack {
            // Profile placeholder (future: actual profile image)
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 24, height: 24)
                .overlay(
                    Text(String(metadata.username.prefix(1)).uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                )

            Text("@\(metadata.username)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let count = metadata.actionCount, count > 1 {
                Text("and \(count - 1) others")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Helper Methods

    private func actionButtonColor(for action: NotificationAction) -> Color {
        switch action {
        case .accept:
            .green
        case .decline:
            .red.opacity(0.2)
        case .reply:
            .blue.opacity(0.2)
        case .kudos:
            .red.opacity(0.2)
        case .view, .dismiss:
            .gray.opacity(0.2)
        }
    }

    private func actionButtonTextColor(for action: NotificationAction) -> Color {
        switch action {
        case .accept:
            .white
        case .decline:
            .red
        case .reply:
            .blue
        case .kudos:
            .red
        case .view, .dismiss:
            .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        // Workout notification
        NotificationRowView(
            notification: FameFitNotification(
                type: .workoutCompleted,
                title: "Workout Complete! 💪",
                body: "Great job on that 30-minute run! You earned 45 XP.",
                metadata: .workout(WorkoutNotificationMetadata(
                    workoutID: "123",
                    workoutType: "Running",
                    duration: 30,
                    calories: 250,
                    xpEarned: 45,
                    distance: 5_000,
                    averageHeartRate: 150
                ))
            ),
            onTap: {},
            onAction: { _ in }
        )

        Divider()

        // Social notification
        NotificationRowView(
            notification: FameFitNotification(
                type: .newFollower,
                title: "New Follower! 👥",
                body: "FitnessGuru started following you",
                metadata: .social(SocialNotificationMetadata(
                    userID: "user123",
                    username: "fitnessguru",
                    displayName: "Fitness Guru",
                    profileImageUrl: nil,
                    relationshipType: "follower",
                    actionCount: nil
                ))
            ),
            onTap: {},
            onAction: { _ in }
        )

        Divider()

        // Achievement notification
        NotificationRowView(
            notification: FameFitNotification(
                type: .unlockAchieved,
                title: "Achievement Unlocked! 🏆",
                body: "You've earned the 'Workout Warrior' achievement!",
                metadata: .achievement(AchievementNotificationMetadata(
                    achievementID: "warrior",
                    achievementName: "Workout Warrior",
                    achievementDescription: "Complete 50 workouts",
                    xpRequired: 1_000,
                    category: "fitness",
                    iconEmoji: "🏆"
                )),
                actions: [.view]
            ),
            onTap: {},
            onAction: { _ in }
        )
    }
    .padding()
}
