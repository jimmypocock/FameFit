//
//  GroupWorkoutActions.swift
//  FameFit
//
//  Action buttons section for group workout card
//

import SwiftUI

struct GroupWorkoutActions: View {
    let groupWorkout: GroupWorkout
    let currentUserID: String?
    let onJoin: () -> Void
    let onLeave: () -> Void
    let onStart: () -> Void

    @State private var showNotStartedAlert = false

    var body: some View {
        HStack(spacing: 12) {
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
            } else if !isParticipant && groupWorkout.status.canJoin && groupWorkout.hasSpace {
                // Join button (only if not already a participant)
                Button(action: {
                    if groupWorkout.isJoinable {
                        onJoin()
                    } else {
                        showNotStartedAlert = true
                    }
                }) {
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
                            .fill(groupWorkout.isJoinable ? Color.blue : Color.gray)
                    )
                }
                .disabled(!groupWorkout.isJoinable)
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
        .alert("Workout Not Started", isPresented: $showNotStartedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The group workout '\(groupWorkout.name)' has not yet started. You can join 5 minutes before the scheduled start time.")
        }
    }

    // Check if the current user is a participant (including host)
    private var isParticipant: Bool {
        guard let currentUserID else { return false }
        // Host is always a participant
        if groupWorkout.hostID == currentUserID {
            return true
        }
        // Check if user is in participantIDs array
        return groupWorkout.participantIDs.contains(currentUserID)
    }

    private var isHost: Bool {
        guard let currentUserID else { return false }
        return groupWorkout.hostID == currentUserID
    }
}