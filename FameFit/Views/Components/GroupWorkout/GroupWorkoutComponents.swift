//
//  GroupWorkoutComponents.swift
//  FameFit
//
//  Small reusable components for group workout cards
//

import SwiftUI

// MARK: - Status Indicator

struct GroupWorkoutStatusIndicator: View {
    let status: GroupWorkoutStatus
    @Binding var isAnimating: Bool

    var body: some View {
        VStack {
            Circle()
                .fill(GroupWorkoutStyleProvider.statusColor(for: status))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(GroupWorkoutStyleProvider.statusColor(for: status).opacity(0.3), lineWidth: 4)
                        .scaleEffect(status == .active ? (isAnimating ? 1.5 : 1.0) : 1.0)
                        .opacity(status == .active ? (isAnimating ? 0 : 1) : 1)
                        .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isAnimating)
                )

            Spacer()
        }
        .frame(width: 20)
    }
}

// MARK: - Timing Info

struct GroupWorkoutTimingInfo: View {
    let groupWorkout: GroupWorkout

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(GroupWorkoutStyleProvider.timeDisplayText(for: groupWorkout.status))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(GroupWorkoutStyleProvider.timeDisplayColor(for: groupWorkout.status))

            if groupWorkout.status == .scheduled {
                Text(groupWorkout.scheduledStart, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Detail Pill

struct GroupWorkoutDetailPill: View {
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

// MARK: - Participant Avatar

struct GroupWorkoutParticipantAvatar: View {
    let participant: GroupWorkoutParticipant
    let index: Int

    var body: some View {
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
}