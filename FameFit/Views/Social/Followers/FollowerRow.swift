//
//  FollowerRow.swift
//  FameFit
//
//  Individual follower row component with profile info and follow button
//

import SwiftUI

struct FollowerRow: View {
    let profile: UserProfile
    let relationshipStatus: RelationshipStatus
    let isProcessing: Bool
    let showFollowButton: Bool
    let onFollowAction: () async -> Void
    let onTap: () -> Void

    @State private var showingProfile = false

    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            profileImage
                .onTapGesture {
                    showingProfile = true
                }

            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.username)
                        .font(.body)
                        .fontWeight(.medium)

                    if profile.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }

                    if relationshipStatus == .mutualFollow {
                        Text("Friends")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }

                Text("@\(profile.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if profile.workoutCount > 0 {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.run")
                                .font(.caption2)
                            Text("\(profile.workoutCount)")
                                .font(.caption2)
                        }

                        Text("•")
                            .font(.caption2)

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption2)
                            Text(formatNumber(profile.totalXP))
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Follow button
            if showFollowButton {
                FollowButton(
                    relationshipStatus: relationshipStatus,
                    isProcessing: isProcessing,
                    onFollowAction: onFollowAction
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            showingProfile = true
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView(userId: profile.id)
        }
    }

    private var profileImage: some View {
        ZStack {
            if profile.profileImageURL != nil {
                // TODO: Implement async image loading
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
            } else {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(profile.initials)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000.0)
        }
        return "\(number)"
    }
}