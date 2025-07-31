//
//  GroupWorkoutCard.swift
//  FameFit
//
//  Card component for displaying group workout sessions
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
            workoutHeader

            // Workout details
            workoutDetails

            // Participants preview
            participantsPreview

            // Action buttons
            actionButtons
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .scaleEffect(isAnimating ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnimating)
        .onTapGesture {
            onViewDetails()
        }
    }

    // MARK: - Header

    private var workoutHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            statusIndicator

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(groupWorkout.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    if !groupWorkout.isPublic {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: workoutTypeIcon)
                        .font(.system(size: 16))
                        .foregroundColor(.blue)

                    Text(workoutTypeDisplayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    if groupWorkout.status == .active {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.green)
                            .opacity(isAnimating ? 0.3 : 1.0)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                                    isAnimating = true
                                }
                            }

                        Text("LIVE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                }

                // Description (if provided)
                if !groupWorkout.description.isEmpty {
                    Text(groupWorkout.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Timing info
            VStack(alignment: .trailing, spacing: 4) {
                Text(timeDisplayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(timeDisplayColor)

                if groupWorkout.status == .scheduled {
                    Text(groupWorkout.scheduledStart, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Workout Details

    private var workoutDetails: some View {
        HStack(spacing: 16) {
            // Duration
            DetailPill(
                icon: "clock",
                value: formatDuration(groupWorkout.duration),
                color: .orange
            )

            // Participants count
            DetailPill(
                icon: "person.2",
                value: "\(groupWorkout.participants.count)/\(groupWorkout.maxParticipants)",
                color: .blue
            )

            // Difficulty or tags (if available)
            if let firstTag = groupWorkout.tags.first {
                DetailPill(
                    icon: "tag",
                    value: firstTag,
                    color: .purple
                )
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Participants Preview

    private var participantsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Participants")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                if groupWorkout.participants.count > 3 {
                    Button("View All (\(groupWorkout.participants.count))") {
                        showParticipants = true
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                }
            }

            // Participant avatars
            HStack(spacing: -8) {
                ForEach(
                    Array(groupWorkout.participants.prefix(4).enumerated()),
                    id: \.element.id
                ) { index, participant in
                    participantAvatar(participant: participant, index: index)
                }

                if groupWorkout.participants.count > 4 {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 32, height: 32)

                        Text("+\(groupWorkout.participants.count - 4)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                }

                Spacer()

                // Host indicator
                if let host = groupWorkout.participants.first(where: { $0.userId == groupWorkout.hostId }) {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)

                        Text("Host: \(host.username)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if isParticipant {
                // Leave button
                Button(action: onLeave) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14))
                        Text("Leave")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.red.opacity(0.1))
                    )
                }

                // Start button (if host and scheduled)
                if isHost, groupWorkout.status == .scheduled {
                    Button(action: onStart) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                            Text("Start")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.green)
                        )
                    }
                }
            } else if groupWorkout.status.canJoin, groupWorkout.hasSpace {
                // Join button
                Button(action: onJoin) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                        Text("Join")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue)
                    )
                }
            }

            Spacer()

            // Share button
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color(.systemGray6))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 12)
    }

    // MARK: - Helper Views

    private var statusIndicator: some View {
        VStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 4)
                        .scaleEffect(groupWorkout.status == .active ? (isAnimating ? 1.5 : 1.0) : 1.0)
                        .opacity(groupWorkout.status == .active ? (isAnimating ? 0 : 1) : 1)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isAnimating)
                )

            Spacer()
        }
        .frame(width: 20)
    }

    private func participantAvatar(participant: GroupWorkoutParticipant, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(participant.username.prefix(1))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                )

            // Status indicator for active participants
            if participant.status == .active {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .offset(x: 10, y: -10)
            }
        }
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 2)
        )
        .zIndex(Double(4 - index)) // Reverse z-order for overlap effect
    }

    private struct DetailPill: View {
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

    // MARK: - Computed Properties

    private var workoutTypeIcon: String {
        switch groupWorkout.workoutType {
        case .running:
            "figure.run"
        case .cycling:
            "bicycle"
        case .swimming:
            "figure.pool.swim"
        case .walking:
            "figure.walk"
        case .hiking:
            "figure.hiking"
        case .yoga:
            "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            "dumbbell"
        default:
            "figure.mixed.cardio"
        }
    }

    private var workoutTypeDisplayName: String {
        switch groupWorkout.workoutType {
        case .running:
            "Running"
        case .walking:
            "Walking"
        case .hiking:
            "Hiking"
        case .cycling:
            "Cycling"
        case .swimming:
            "Swimming"
        case .functionalStrengthTraining:
            "Strength Training"
        case .traditionalStrengthTraining:
            "Weight Training"
        case .yoga:
            "Yoga"
        case .pilates:
            "Pilates"
        case .dance:
            "Dance"
        case .boxing:
            "Boxing"
        case .kickboxing:
            "Kickboxing"
        default:
            "Workout"
        }
    }

    private var statusColor: Color {
        switch groupWorkout.status {
        case .scheduled:
            .blue
        case .active:
            .green
        case .completed:
            .gray
        case .cancelled:
            .red
        }
    }

    private var backgroundColor: Color {
        switch groupWorkout.status {
        case .active:
            Color.green.opacity(0.05)
        case .scheduled:
            Color(.systemBackground)
        case .completed:
            Color(.systemGray6)
        case .cancelled:
            Color.red.opacity(0.05)
        }
    }

    private var shadowColor: Color {
        switch groupWorkout.status {
        case .active:
            .green.opacity(0.2)
        case .scheduled:
            .black.opacity(0.1)
        default:
            .clear
        }
    }

    private var shadowRadius: CGFloat {
        groupWorkout.status == .active ? 8 : 4
    }

    private var shadowOffset: CGFloat {
        groupWorkout.status == .active ? 4 : 2
    }

    private var borderColor: Color {
        switch groupWorkout.status {
        case .active:
            .green.opacity(0.3)
        default:
            .clear
        }
    }

    private var borderWidth: CGFloat {
        groupWorkout.status == .active ? 1 : 0
    }

    private var timeDisplayText: String {
        switch groupWorkout.status {
        case .scheduled:
            "Starts"
        case .active:
            "Live"
        case .completed:
            "Ended"
        case .cancelled:
            "Cancelled"
        }
    }

    private var timeDisplayColor: Color {
        switch groupWorkout.status {
        case .scheduled:
            .blue
        case .active:
            .green
        case .completed:
            .secondary
        case .cancelled:
            .red
        }
    }

    private var isParticipant: Bool {
        guard let currentUserId else { return false }
        return groupWorkout.participantIds.contains(currentUserId)
    }

    private var isHost: Bool {
        guard let currentUserId else { return false }
        return groupWorkout.hostId == currentUserId
    }

    // MARK: - Helper Methods

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3_600
        let minutes = (Int(duration) % 3_600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

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
