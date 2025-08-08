//
//  GroupWorkoutParticipants.swift
//  FameFit
//
//  Participants preview section with avatars and host indicator
//

import SwiftUI

struct GroupWorkoutCardParticipants: View {
    let groupWorkout: GroupWorkout
    let participants: [GroupWorkoutParticipant] // Now passed separately
    @Binding var showParticipants: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Remove "Participants" text per requirements

            // Participant avatars
            HStack(spacing: -8) {
                ForEach(
                    Array(participants.prefix(4).enumerated()),
                    id: \.element.id
                ) { index, participant in
                    GroupWorkoutParticipantAvatar(
                        participant: participant,
                        index: index
                    )
                }

                if participants.count > 4 {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 32, height: 32)

                        Text("+\(participants.count - 4)")
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
                if let host = participants.first(where: { $0.userID == groupWorkout.hostID }) {
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
}
