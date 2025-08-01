import SwiftUI

struct NotificationsListView: View {
    @EnvironmentObject var notificationStore: NotificationStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Group {
                if notificationStore.notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)

                        Text("No Notifications")
                            .font(.title2)
                            .fontWeight(.medium)

                        Text("Your notifications will appear here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(notificationStore.notifications) { notification in
                            NotificationRow(notification: notification)
                        }
                        .onDelete(perform: deleteNotifications)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !notificationStore.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: {
                                notificationStore.clearAll()
                            }) {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .onAppear {
            // Mark all as read when viewing
            notificationStore.markAllAsRead()
        }
    }

    private func deleteNotifications(at offsets: IndexSet) {
        notificationStore.deleteFameFitNotification(at: offsets)
    }
}

struct NotificationRow: View {
    let notification: FameFitNotification

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(notification.character?.emoji ?? notification.type.icon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(notification.timestamp.relativeDisplayString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }

            Text(notification.body)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack(spacing: 20) {
                // Show workout-specific details if available
                if let duration = notification.workoutDuration {
                    Label("\(duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let calories = notification.calories {
                    Label("\(calories) cal", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let xp = notification.followersEarned {
                    Label("+\(xp) XP", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NotificationsListView()
        .environmentObject(NotificationStore())
}
