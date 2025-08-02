//
//  FollowersListContent.swift
//  FameFit
//
//  Main list content component for displaying followers
//

import SwiftUI

struct FollowersListContent: View {
    let profiles: [UserProfile]
    let followingStatuses: [String: RelationshipStatus]
    let pendingActions: Set<String>
    let currentUserId: String?
    let onFollowAction: (UserProfile) async -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(profiles) { profile in
                    FollowerRow(
                        profile: profile,
                        relationshipStatus: followingStatuses[profile.id] ?? .notFollowing,
                        isProcessing: pendingActions.contains(profile.id),
                        showFollowButton: currentUserId != nil && profile.id != currentUserId
                    ) {
                        await onFollowAction(profile)
                    } onTap: {
                        // Navigate to profile handled in FollowerRow
                    }

                    if profile.id != profiles.last?.id {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
        }
    }
}