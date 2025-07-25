//
//  NotificationCenterView.swift
//  FameFit
//
//  In-app notification center for viewing all notifications
//

import SwiftUI

struct NotificationCenterView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container
    @StateObject private var viewModel = NotificationCenterViewModel()

    @State private var showingSettings = false
    @State private var selectedTab = 0
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Filter", selection: $selectedTab) {
                    Text("All").tag(0)
                    Text("Unread").tag(1)
                    Text("Social").tag(2)
                    Text("Workouts").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // Notifications list with animations
                if viewModel.isLoading, viewModel.notifications.isEmpty {
                    loadingView
                        .transition(.opacity)
                } else if viewModel.filteredNotifications(for: selectedTab).isEmpty {
                    emptyStateView
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.filteredNotifications(for: selectedTab)) { notification in
                                NotificationRowView(
                                    notification: notification,
                                    onTap: {
                                        hapticFeedback(.light)
                                        viewModel.handleNotificationTap(notification)
                                    },
                                    onAction: { action in
                                        hapticFeedback(.medium)
                                        handleNotificationAction(notification: notification, action: action)
                                    }
                                )
                                .onAppear {
                                    if !notification.isRead {
                                        viewModel.markAsRead(notification.id)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))

                                if notification.id != viewModel.filteredNotifications(for: selectedTab).last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                        .refreshable {
                            await refreshNotifications()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All Read") {
                            hapticFeedback(.heavy)
                            viewModel.markAllAsRead()
                        }

                        Button("Settings") {
                            showingSettings = true
                        }

                        Button("Clear All", role: .destructive) {
                            hapticFeedback(.heavy)
                            viewModel.clearAllNotifications()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: selectedTab)
            .animation(.easeInOut(duration: 0.3), value: viewModel.notifications.count)
        }
        .sheet(isPresented: $showingSettings) {
            NotificationSettingsView()
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .task {
            viewModel.configure(notificationStore: container.notificationStore)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 120)

                Image(systemName: getEmptyStateIcon())
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                Text(getEmptyStateTitle())
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(getEmptyStateMessage())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineLimit(nil)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func getEmptyStateIcon() -> String {
        switch selectedTab {
        case 1: "bell.badge"
        case 2: "person.2"
        case 3: "figure.run"
        default: "bell"
        }
    }

    private func getEmptyStateTitle() -> String {
        switch selectedTab {
        case 1: "No Unread Notifications"
        case 2: "No Social Activity"
        case 3: "No Workout Notifications"
        default: "No Notifications"
        }
    }

    private func getEmptyStateMessage() -> String {
        switch selectedTab {
        case 1: "All caught up! You have no unread notifications."
        case 2: "Social notifications like follows, kudos, and comments will appear here."
        case 3: "Workout completion notifications and achievements will appear here."
        default: "Your notifications will appear here when you receive them."
        }
    }

    private var loadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 80, height: 80)

                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            }

            VStack(spacing: 6) {
                Text("Loading notifications...")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text("Fetching your latest updates")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Helper Methods

    private func handleNotificationAction(notification: NotificationItem, action: NotificationAction) {
        viewModel.handleNotificationAction(notification, action: action)
    }

    private func refreshNotifications() async {
        hapticFeedback(.light)
        // Add a small delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        await MainActor.run {
            viewModel.loadNotifications()
        }
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Preview

#Preview {
    NotificationCenterView()
        .environment(\.dependencyContainer, DependencyContainer())
}
