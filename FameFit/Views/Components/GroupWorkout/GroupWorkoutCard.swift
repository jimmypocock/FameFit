//
//  GroupWorkoutCard.swift
//  FameFit
//
//  Main card component for displaying group workout sessions
//

import HealthKit
import SwiftUI

struct GroupWorkoutCard: View {
    let groupWorkout: GroupWorkout
    
    @Environment(\.dependencyContainer) private var container
    @State private var isAnimating = false
    @State private var hostUsername: String = "Loading..."

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with workout info
            GroupWorkoutCardHeader(
                groupWorkout: groupWorkout,
                isAnimating: $isAnimating
            )
            
            // Host info at bottom - always show
            Text("Hosted by: \(hostUsername)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .padding(.top, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GroupWorkoutStyleProvider.backgroundColor(for: groupWorkout.status))
                .shadow(
                    color: GroupWorkoutStyleProvider.shadowColor(for: groupWorkout.status),
                    radius: GroupWorkoutStyleProvider.shadowRadius(for: groupWorkout.status),
                    x: 0,
                    y: GroupWorkoutStyleProvider.shadowOffset(for: groupWorkout.status)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    GroupWorkoutStyleProvider.borderColor(for: groupWorkout.status),
                    lineWidth: GroupWorkoutStyleProvider.borderWidth(for: groupWorkout.status)
                )
        )
        .scaleEffect(isAnimating ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnimating)
        .onAppear {
            loadHostUsername()
        }
    }
    
    private func loadHostUsername() {
        Task {
            do {
                print("Loading host username for hostID: \(groupWorkout.hostID)")
                // Use fetchProfileByUserID for CloudKit user IDs (starting with underscore)
                let profile = try await container.userProfileService.fetchProfileByUserID(groupWorkout.hostID)
                await MainActor.run {
                    hostUsername = profile.username
                    print("Successfully loaded host username: \(profile.username)")
                }
            } catch {
                print("Failed to load host username for \(groupWorkout.hostID): \(error)")
                await MainActor.run {
                    // Show hostID as fallback
                    hostUsername = "Unknown"
                }
            }
        }
    }
}

// MARK: - Preview

/*
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Scheduled workout
            GroupWorkoutCard(
                groupWorkout: GroupWorkout(
                    name: "Morning Run Club",
                    description: "Join us for an energizing morning run through the park. All fitness levels welcome!",
                    workoutType: .running,
                    hostID: "host1",
                    participants: [
                        GroupWorkoutParticipant(
                            userID: "host1",
                            username: "SarahWilson",
                            profileImageURL: nil
                        ),
                        GroupWorkoutParticipant(
                            userID: "user2",
                            username: "MikeJohnson",
                            profileImageURL: nil
                        ),
                        GroupWorkoutParticipant(
                            userID: "user3",
                            username: "EmmaChen",
                            profileImageURL: nil
                        )
                    ],
                    maxParticipants: 8,
                    scheduledStart: Date().addingTimeInterval(3_600),
                    scheduledEnd: Date().addingTimeInterval(7_200),
                    isPublic: true,
                    tags: ["Beginner", "Outdoor"]
                ),
                currentUserID: "currentUser",
                onJoin: {},
                onLeave: {},
                onStart: {},
                onViewDetails: {}
            )

            // Active workout
            GroupWorkoutCard(
                groupWorkout: GroupWorkout(
                    name: "HIIT Challenge",
                    description: "High-intensity interval training session",
                    workoutType: .functionalStrengthTraining,
                    hostID: "host2",
                    participants: [
                        GroupWorkoutParticipant(
                            userID: "host2",
                            username: "CoachAlex",
                            profileImageURL: nil,
                            status: .active
                        ),
                        GroupWorkoutParticipant(
                            userID: "currentUser",
                            username: "CurrentUser",
                            profileImageURL: nil,
                            status: .active
                        )
                    ],
                    maxParticipants: GroupWorkoutConstants.defaultMaxParticipants,
                    scheduledStart: Date().addingTimeInterval(-1_800),
                    scheduledEnd: Date().addingTimeInterval(1_800),
                    status: .active,
                    isPublic: false,
                    tags: ["Advanced", "Indoor"]
                ),
                currentUserID: "currentUser",
                onJoin: {},
                onLeave: {},
                onStart: {},
                onViewDetails: {}
            )
        }
        .padding()
    }
}
*/
