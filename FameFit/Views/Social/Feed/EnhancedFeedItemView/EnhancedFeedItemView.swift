//
//  EnhancedFeedItemView.swift
//  FameFit
//
//  Enhanced visual feed item with rich animations and modern design
//

import SwiftUI

struct EnhancedFeedItemView: View {
    let item: FeedItem
    let onProfileTap: () -> Void
    let onKudosTap: (FeedItem) async -> Void
    let onCommentsTap: (FeedItem) -> Void

    @State private var showKudosAnimation = false
    @State private var kudosScale: CGFloat = 1.0
    @State private var showCelebration = false

    var body: some View {
        VStack(spacing: 0) {
            switch item.type {
            case .workout:
                EnhancedWorkoutCard(
                    item: item,
                    onProfileTap: onProfileTap,
                    onKudosTap: onKudosTap,
                    onCommentsTap: onCommentsTap,
                    showKudosAnimation: $showKudosAnimation,
                    kudosScale: $kudosScale
                )
            case .achievement:
                EnhancedAchievementCard(
                    item: item,
                    onProfileTap: onProfileTap,
                    showCelebration: $showCelebration
                )
            case .levelUp:
                EnhancedLevelUpCard(
                    item: item,
                    onProfileTap: onProfileTap
                )
            case .milestone:
                EnhancedMilestoneCard(
                    item: item,
                    onProfileTap: onProfileTap
                )
            case .challenge, .groupWorkout:
                // TODO: Add specific cards for challenges and group workouts
                EnhancedWorkoutCard(
                    item: item,
                    onProfileTap: onProfileTap,
                    onKudosTap: onKudosTap,
                    onCommentsTap: onCommentsTap,
                    showKudosAnimation: $showKudosAnimation,
                    kudosScale: $kudosScale
                )
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}