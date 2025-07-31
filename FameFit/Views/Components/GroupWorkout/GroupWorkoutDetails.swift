//
//  GroupWorkoutDetails.swift
//  FameFit
//
//  Details section with duration, participants count, and tags
//

import SwiftUI

struct GroupWorkoutDetails: View {
    let groupWorkout: GroupWorkout

    var body: some View {
        HStack(spacing: 16) {
            // Duration
            GroupWorkoutDetailPill(
                icon: "clock",
                value: formatDuration(groupWorkout.duration),
                color: .orange
            )

            // Participants count
            GroupWorkoutDetailPill(
                icon: "person.2",
                value: "\(groupWorkout.participants.count)/\(groupWorkout.maxParticipants)",
                color: .blue
            )

            // Difficulty or tags (if available)
            if let firstTag = groupWorkout.tags.first {
                GroupWorkoutDetailPill(
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