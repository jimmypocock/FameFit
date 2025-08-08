//
//  NotificationDebugView.swift
//  FameFit
//
//  Debug tools for notification system
//

import SwiftUI
import UserNotifications

struct NotificationDebugView: View {
    @Environment(\.dependencyContainer) private var dependencies
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var deviceTokenStatus = "Unknown"
    @State private var badgeCount = 0
    @State private var pendingNotifications: [UNNotificationRequest] = []
    @State private var deliveredNotifications: [UNNotification] = []
    @State private var isLoading = false
    @State private var testMessage = ""

    var body: some View {
        NavigationView {
            List {
                permissionSection
                deviceTokenSection
                badgeSection
                notificationQueuesSection
                testingSection
                troubleshootingSection
            }
            .navigationTitle("Notification Debug")
            .onAppear {
                checkStatus()
            }
            .refreshable {
                await refreshStatus()
            }
        }
    }

    // MARK: - Sections

    private var permissionSection: some View {
        Section("Permission Status") {
            HStack {
                Text("Authorization Status")
                Spacer()
                Text(statusDescription)
                    .foregroundColor(statusColor)
                    .fontWeight(.semibold)
            }

            if notificationStatus != .authorized {
                Button("Request Permission") {
                    requestPermission()
                }
                .foregroundColor(.blue)
            }

            Button("Open Settings") {
                openNotificationSettings()
            }
            .foregroundColor(.secondary)
        }
    }

    private var deviceTokenSection: some View {
        Section("Push Notifications") {
            HStack {
                Text("Device Token")
                Spacer()
                Text(deviceTokenStatus)
                    .foregroundColor(deviceTokenStatus == "Registered" ? .green : .orange)
                    .fontWeight(.semibold)
            }

            Button("Re-register for Push") {
                reregisterForPush()
            }
            .foregroundColor(.blue)
        }
    }

    private var badgeSection: some View {
        Section("Badge Management") {
            HStack {
                Text("Current Badge Count")
                Spacer()
                Text("\(badgeCount)")
                    .fontWeight(.semibold)
            }

            HStack {
                Button("Clear Badge") {
                    clearBadge()
                }
                .foregroundColor(.red)

                Spacer()

                Button("Set Badge to 5") {
                    setBadgeCount(5)
                }
                .foregroundColor(.blue)
            }
        }
    }

    private var notificationQueuesSection: some View {
        Section("Notification Queues") {
            NavigationLink(destination: PendingNotificationsView(notifications: pendingNotifications)) {
                HStack {
                    Text("Pending Notifications")
                    Spacer()
                    Text("\(pendingNotifications.count)")
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }

            NavigationLink(destination: DeliveredNotificationsView(notifications: deliveredNotifications)) {
                HStack {
                    Text("Delivered Notifications")
                    Spacer()
                    Text("\(deliveredNotifications.count)")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }

            Button("Clear All Notifications") {
                clearAllNotifications()
            }
            .foregroundColor(.red)
        }
    }

    private var testingSection: some View {
        Section("Test Notifications") {
            TextField("Test message", text: $testMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            VStack(spacing: 8) {
                Button("Send Test Workout Notification") {
                    sendTestWorkoutFameFitNotification()
                }
                .foregroundColor(.blue)

                Button("Send Test Social Notification") {
                    sendTestSocialFameFitNotification()
                }
                .foregroundColor(.green)

                Button("Send Test Achievement Notification") {
                    sendTestAchievementFameFitNotification()
                }
                .foregroundColor(.purple)
            }
        }
    }

    private var troubleshootingSection: some View {
        Section("Troubleshooting") {
            VStack(alignment: .leading, spacing: 12) {
                troubleshootingItem(
                    title: "No Notifications Received",
                    steps: [
                        "Check notification permissions in Settings",
                        "Ensure Do Not Disturb is disabled",
                        "Restart the app",
                        "Re-register for push notifications"
                    ]
                )

                troubleshootingItem(
                    title: "Badge Count Not Updating",
                    steps: [
                        "Check notification settings allow badges",
                        "Try clearing and setting badge manually",
                        "Restart device if needed"
                    ]
                )

                troubleshootingItem(
                    title: "Push Notifications Not Working",
                    steps: [
                        "Check internet connection",
                        "Verify device token registration",
                        "Test with local notifications first"
                    ]
                )
            }
        }
    }

    // MARK: - Helper Views

    private func troubleshootingItem(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    Text(step)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Computed Properties

    private var statusDescription: String {
        switch notificationStatus {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Asked"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }

    private var statusColor: Color {
        switch notificationStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .provisional:
            return .yellow
        case .ephemeral:
            return .blue
        @unknown default:
            return .gray
        }
    }

    // MARK: - Actions

    private func checkStatus() {
        isLoading = true

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()

            await MainActor.run {
                notificationStatus = settings.authorizationStatus
                badgeCount = dependencies.notificationStore.unreadCount

                loadNotificationQueues()
                checkDeviceTokenStatus()

                isLoading = false
            }
        }
    }

    private func refreshStatus() async {
        checkStatus()
    }

    private func loadNotificationQueues() {
        Task {
            let center = UNUserNotificationCenter.current()

            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()

            await MainActor.run {
                pendingNotifications = pending
                deliveredNotifications = delivered
            }
        }
    }

    private func checkDeviceTokenStatus() {
        // This would require accessing the APNS manager's device token status
        // For now, we'll show a placeholder
        deviceTokenStatus = "Check APNS Manager"
    }

    private func requestPermission() {
        Task {
            let granted = await dependencies.notificationManager.requestNotificationPermission()

            await MainActor.run {
                if granted {
                    checkStatus()
                }
            }
        }
    }

    private func openNotificationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    private func reregisterForPush() {
        dependencies.apnsManager.registerForRemoteNotifications()
        checkDeviceTokenStatus()
    }

    private func clearBadge() {
        Task {
            await dependencies.apnsManager.updateBadgeCount(0)

            await MainActor.run {
                badgeCount = 0
            }
        }
    }

    private func setBadgeCount(_ count: Int) {
        Task {
            await dependencies.apnsManager.updateBadgeCount(count)

            await MainActor.run {
                badgeCount = count
            }
        }
    }

    private func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        dependencies.notificationStore.clearAll()

        loadNotificationQueues()
    }

    private func sendTestWorkoutFameFitNotification() {
        let testWorkout = Workout(
            id: UUID(),
            workoutType: "Running",
            startDate: Date().addingTimeInterval(-1_800), // 30 minutes ago
            endDate: Date(),
            duration: 1_800, // 30 minutes
            totalEnergyBurned: 300,
            totalDistance: 5_000, // 5km
            averageHeartRate: 145,
            followersEarned: 25,
            xpEarned: 25,
            source: "FameFit Debug"
        )

        Task {
            await dependencies.notificationManager.notifyWorkoutCompleted(testWorkout)
            await refreshStatus()
        }
    }

    private func sendTestSocialFameFitNotification() {
        let testUser = UserProfile(
            id: "debug-user",
            userID: "debug-user",
            username: "debuguser",
            bio: "Test user for debugging",
            workoutCount: 50,
            totalXP: 1_500,
            creationDate: Date().addingTimeInterval(-86_400 * 30), // 30 days ago
            modificationDate: Date(),
            isVerified: false,
            privacyLevel: .publicProfile
        )

        Task {
            await dependencies.notificationManager.notifyNewFollower(from: testUser)
            await refreshStatus()
        }
    }

    private func sendTestAchievementFameFitNotification() {
        Task {
            await dependencies.notificationManager.notifyXPMilestone(previousXP: 950, currentXP: 1_050)
            await refreshStatus()
        }
    }
}

// MARK: - Supporting Views

struct PendingNotificationsView: View {
    let notifications: [UNNotificationRequest]

    var body: some View {
        List(notifications, id: \.identifier) { notification in
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.content.title)
                    .font(.headline)

                Text(notification.content.body)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let triggerDate = (notification.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() {
                    Text("Scheduled: \(triggerDate, formatter: dateFormatter)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("Pending (\(notifications.count))")
    }
}

struct DeliveredNotificationsView: View {
    let notifications: [UNNotification]

    var body: some View {
        List(notifications, id: \.request.identifier) { notification in
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.request.content.title)
                    .font(.headline)

                Text(notification.request.content.body)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Delivered: \(notification.date, formatter: dateFormatter)")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("Delivered (\(notifications.count))")
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    NotificationDebugView()
        .environment(\.dependencyContainer, DependencyContainer())
}
