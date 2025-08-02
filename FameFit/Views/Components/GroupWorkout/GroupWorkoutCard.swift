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
    let currentUserId: String?
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onStart: () -> Void
    let onViewDetails: () -> Void

    @State private var showParticipants = false
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with workout info
            GroupWorkoutHeader(
                groupWorkout: groupWorkout,
                isAnimating: $isAnimating
            )

            // Workout details
            GroupWorkoutDetails(groupWorkout: groupWorkout)

            // Participants preview
            GroupWorkoutParticipants(
                groupWorkout: groupWorkout,
                participants: [], // TODO: Fetch participants from CloudKit
                showParticipants: $showParticipants
            )

            // Action buttons
            GroupWorkoutActions(
                groupWorkout: groupWorkout,
                currentUserId: currentUserId,
                onJoin: onJoin,
                onLeave: onLeave,
                onStart: onStart
            )
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
        .onTapGesture {
            onViewDetails()
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
                    hostId: "host1",
                    participants: [
                        GroupWorkoutParticipant(
                            userId: "host1",
                            username: "SarahWilson",
                            profileImageURL: nil
                        ),
                        GroupWorkoutParticipant(
                            userId: "user2",
                            username: "MikeJohnson",
                            profileImageURL: nil
                        ),
                        GroupWorkoutParticipant(
                            userId: "user3",
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
                currentUserId: "currentUser",
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
                    hostId: "host2",
                    participants: [
                        GroupWorkoutParticipant(
                            userId: "host2",
                            username: "CoachAlex",
                            profileImageURL: nil,
                            status: .active
                        ),
                        GroupWorkoutParticipant(
                            userId: "currentUser",
                            username: "CurrentUser",
                            profileImageURL: nil,
                            status: .active
                        )
                    ],
                    maxParticipants: 10,
                    scheduledStart: Date().addingTimeInterval(-1_800),
                    scheduledEnd: Date().addingTimeInterval(1_800),
                    status: .active,
                    isPublic: false,
                    tags: ["Advanced", "Indoor"]
                ),
                currentUserId: "currentUser",
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