//
//  NotificationSettingsView.swift
//  FameFit
//
//  Settings view for notification preferences
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    @State private var preferences = NotificationSettings()
    @State private var isLoading = false
    @State private var pushNotificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showPermissionView = false

    var body: some View {
        NavigationStack {
            Form {
                // Push Notification Status Section
                Section {
                    HStack {
                        Label("Push Notifications", systemImage: "bell.badge")
                        Spacer()
                        Text(statusText)
                            .foregroundColor(statusColor)
                            .font(.caption)
                    }

                    if pushNotificationStatus == .denied {
                        Button("Open Settings") {
                            openSettings()
                        }
                        .foregroundColor(.orange)
                    } else if pushNotificationStatus == .notDetermined {
                        Button("Enable Push Notifications") {
                            showPermissionView = true
                        }
                        .foregroundColor(.orange)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Push Notifications")
                        .font(.headline)
                        .padding(.top)

                    Toggle("Allow Notifications", isOn: $preferences.pushNotificationsEnabled)
                        .onChange(of: preferences.pushNotificationsEnabled) { _, newValue in
                            if newValue {
                                requestNotificationPermission()
                            }
                        }

                    if preferences.pushNotificationsEnabled {
                        Toggle("Show on Lock Screen", isOn: $preferences.showPreviewsWhenLocked)
                        Toggle("Play Sound", isOn: $preferences.soundEnabled)
                        Toggle("Show Badge", isOn: $preferences.badgeEnabled)
                    }
                }

                if preferences.pushNotificationsEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notification Types")
                            .font(.headline)
                            .padding(.top)
                        notificationTypeToggles
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quiet Hours")
                            .font(.headline)
                            .padding(.top)

                        Toggle("Enable Quiet Hours", isOn: $preferences.quietHoursEnabled)

                        if preferences.quietHoursEnabled {
                            DatePicker(
                                "Start Time",
                                selection: Binding(
                                    get: { preferences.quietHoursStart ?? Calendar.current.date(
                                        bySettingHour: 22,
                                        minute: 0,
                                        second: 0,
                                        of: Date()
                                    )!
                                    },
                                    set: { preferences.quietHoursStart = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )

                            DatePicker(
                                "End Time",
                                selection: Binding(
                                    get: { preferences.quietHoursEnd ?? Calendar.current.date(
                                        bySettingHour: 8,
                                        minute: 0,
                                        second: 0,
                                        of: Date()
                                    )!
                                    },
                                    set: { preferences.quietHoursEnd = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rate Limiting")
                            .font(.headline)
                            .padding(.top)

                        Stepper(
                            "Max per Hour: \(preferences.maxNotificationsPerHour)",
                            value: $preferences.maxNotificationsPerHour,
                            in: 1 ... 60
                        )

                        Stepper(
                            "Max per Day: \(preferences.maxNotificationsPerDay)",
                            value: $preferences.maxNotificationsPerDay,
                            in: 10 ... 500
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Notification History")
                        .font(.headline)
                        .padding(.top)

                    HStack {
                        Text("Keep History")
                        Spacer()
                        Picker("Keep History", selection: $preferences.historyRetentionDays) {
                            Text("1 Week").tag(7)
                            Text("2 Weeks").tag(14)
                            Text("1 Month").tag(30)
                            Text("3 Months").tag(90)
                        }
                        .pickerStyle(.menu)
                    }

                    Button("Clear All Notifications") {
                        clearAllNotifications()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }
            }
        }
        .task {
            loadPreferences()
            await checkPushNotificationStatus()
        }
        .sheet(isPresented: $showPermissionView) {
            NotificationPermissionView {
                Task {
                    await checkPushNotificationStatus()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var statusText: String {
        switch pushNotificationStatus {
        case .notDetermined:
            return "Not Set"
        case .denied:
            return "Disabled"
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Temporary"
        @unknown default:
            return "Unknown"
        }
    }

    private var statusColor: Color {
        switch pushNotificationStatus {
        case .authorized, .provisional:
            return .green
        case .denied:
            return .red
        case .notDetermined, .ephemeral:
            return .orange
        @unknown default:
            return .gray
        }
    }

    @ViewBuilder
    private var notificationTypeToggles: some View {
        ForEach(NotificationType.allCases, id: \.self) { type in
            if type != .maintenanceNotice, type != .securityAlert { // System types not user-configurable
                Toggle(type.displayName, isOn: binding(for: type))
            }
        }
    }

    // MARK: - Helper Methods

    private func binding(for type: NotificationType) -> Binding<Bool> {
        Binding(
            get: { preferences.isNotificationTypeEnabled(type) },
            set: { enabled in
                preferences.enabledTypes[type] = enabled
            }
        )
    }

    private func loadPreferences() {
        isLoading = true
        // Load saved preferences from UserDefaults
        preferences = NotificationSettings.load()
        isLoading = false
    }

    private func savePreferences() {
        isLoading = true
        // Save preferences to UserDefaults
        preferences.save()

        // Update notification scheduler with new preferences
        container.notificationScheduler.updatePreferences(preferences)

        // Also update notification manager, unlock service, and workout observer
        container.notificationManager.updatePreferences(preferences)
        container.unlockNotificationService.updatePreferences(preferences)
        container.workoutObserver.updatePreferences(preferences)

        isLoading = false
    }

    private func requestNotificationPermission() {
        Task {
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])

                await MainActor.run {
                    if !granted {
                        preferences.pushNotificationsEnabled = false
                    }
                }
            } catch {
                await MainActor.run {
                    preferences.pushNotificationsEnabled = false
                }
            }
        }
    }

    private func clearAllNotifications() {
        container.notificationStore.clearAllNotifications()
    }

    private func checkPushNotificationStatus() async {
        let status = container.apnsManager.notificationAuthorizationStatus
        await MainActor.run {
            pushNotificationStatus = status
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationSettingsView()
        .environment(\.dependencyContainer, DependencyContainer())
}
