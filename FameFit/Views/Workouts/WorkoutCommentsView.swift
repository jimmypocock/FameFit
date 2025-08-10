//
//  WorkoutCommentsView.swift
//  FameFit
//
//  Full-screen comments view for workout interactions
//

import SwiftUI
import Foundation

// MARK: - Temporary Date Extension (TODO: Fix Shared extension access)
private extension Date {
    var relativeDisplayString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

struct WorkoutCommentsView: View {
    let workout: Workout
    let workoutOwner: UserProfile?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencyContainer) private var container

    @State private var currentUser: UserProfile?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Workout context header
                workoutHeader

                // Comments list
                CommentsListView(
                    workoutID: workout.id,
                    workoutOwnerID: workoutOwner?.id ?? "",
                    currentUser: currentUser,
                    commentsService: container.activityCommentsService
                )
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            // Share workout
                        }) {
                            Label("Share Workout", systemImage: "square.and.arrow.up")
                        }

                        Button(action: {
                            // Report inappropriate content
                        }) {
                            Label("Report", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadCurrentUser()
        }
    }

    // MARK: - Workout Header

    private var workoutHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Workout owner profile
                if let owner = workoutOwner {
                    AsyncImage(url: owner.profileImageURL.flatMap { URL(string: $0) }) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                Text(owner.username.prefix(1))
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.blue)
                            )
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(owner.username)
                                .font(.system(size: 16, weight: .semibold))

                            if owner.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }

                        Text("@\(owner.username)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Workout time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(workout.startDate.relativeDisplayString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Workout summary
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: workoutIcon(for: workout.workoutType))
                        .font(.system(size: 20))
                        .foregroundColor(.blue)

                    Text(workout.workoutType)
                        .font(.system(size: 18, weight: .semibold))
                }

                Spacer()

                Text("+\(workout.effectiveXPEarned) XP")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
            }

            // Quick stats
            HStack(spacing: 16) {
                StatPill(
                    icon: "clock",
                    value: workout.formattedDuration,
                    color: .orange
                )

                StatPill(
                    icon: "flame",
                    value: workout.formattedCalories,
                    color: .red
                )

                if let distance = workout.formattedDistance {
                    StatPill(
                        icon: "location",
                        value: distance,
                        color: .blue
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }

    // MARK: - Helper Views

    private struct StatPill: View {
        let icon: String
        let value: String
        let color: Color

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
        }
    }

    // MARK: - Helper Methods

    private func workoutIcon(for type: String) -> String {
        switch type.lowercased() {
        case "running":
            "figure.run"
        case "cycling":
            "bicycle"
        case "swimming":
            "figure.pool.swim"
        case "walking":
            "figure.walk"
        case "hiking":
            "figure.hiking"
        case "yoga":
            "figure.yoga"
        case "strength training", "functional strength training", "traditional strength training":
            "dumbbell"
        default:
            "figure.mixed.cardio"
        }
    }

    private func loadCurrentUser() {
        Task {
            do {
                if let userID = container.cloudKitManager.currentUserID {
                    // userID is from cloudKitManager, so it's a CloudKit user ID
                    currentUser = try await container.userProfileService.fetchProfileByUserID(userID)
                }
            } catch {
                print("Failed to load current user: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutCommentsView(
        workout: Workout(
            id: UUID().uuidString,
            workoutType: "Running",
            startDate: Date().addingTimeInterval(-3_600),
            endDate: Date(),
            duration: 3_600,
            totalEnergyBurned: 450,
            totalDistance: 8_000,
            averageHeartRate: 155,
            followersEarned: 15,
            xpEarned: 25,
            source: "Apple Watch"
        ),
        workoutOwner: UserProfile(
            id: "owner123",
            userID: "owner123",
            username: "runner_sam",
            bio: "Marathon enthusiast",
            workoutCount: 312,
            totalXP: 12_500,
            creationDate: Date().addingTimeInterval(-86_400 * 500),
            modificationDate: Date(),
            isVerified: true,
            privacyLevel: .publicProfile,
            profileImageURL: nil
        )
    )
}
