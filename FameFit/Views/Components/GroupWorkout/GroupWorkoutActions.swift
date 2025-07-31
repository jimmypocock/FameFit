//
//  GroupWorkoutActions.swift
//  FameFit
//
//  Action buttons section for group workout card
//

import SwiftUI

struct GroupWorkoutActions: View {
    let groupWorkout: GroupWorkout
    let currentUserId: String?
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onStart: () -> Void

    var body: some View {
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

    private var isParticipant: Bool {
        guard let currentUserId else { return false }
        return groupWorkout.participantIds.contains(currentUserId)
    }

    private var isHost: Bool {
        guard let currentUserId else { return false }
        return groupWorkout.hostId == currentUserId
    }
}