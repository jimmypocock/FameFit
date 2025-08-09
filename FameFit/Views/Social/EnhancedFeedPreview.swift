//
//  EnhancedFeedPreview.swift
//  FameFit
//
//  Preview of the enhanced feed for testing
//

import SwiftUI

struct EnhancedFeedPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(sampleFeedItems) { item in
                    EnhancedFeedItemView(
                        item: item,
                        onProfileTap: {
                            print("Profile tapped")
                        },
                        onKudosTap: { _ in
                            print("Kudos tapped")
                        },
                        onCommentsTap: { _ in
                            print("Comments tapped")
                        }
                    )
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var sampleFeedItems: [ActivityFeedItem] {
        [
            // Running workout with PR
            ActivityFeedItem(
                id: "1",
                userID: "user1",
                username: "speedster",
                userProfile: UserProfile(
                    id: "user1",
                    userID: "user1",
                    username: "speedster",
                    bio: "Marathon enthusiast",
                    workoutCount: 156,
                    totalXP: 45_000,
                    creationDate: Date(),
                    modificationDate: Date(),
                    isVerified: true,
                    privacyLevel: .publicProfile,
                    profileImageURL: nil,
                    headerImageURL: nil
                ),
                type: .workout,
                timestamp: Date().addingTimeInterval(-3_600),
                content: ActivityFeedContent(
                    title: "Morning Run 🌅",
                    subtitle: "Crushed my 5K personal record! Coach Alex is proud! 🎉",
                    details: [
                        "workoutType": "Running",
                        "duration": "1560", // 26 minutes
                        "calories": "320",
                        "xpEarned": "85"
                    ]
                ),
                workoutID: "1",
                kudosCount: 12,
                commentCount: 5,
                hasKudoed: false,
                kudosSummary: WorkoutKudosSummary(
                    workoutID: "1",
                    totalCount: 12,
                    hasUserKudos: false,
                    recentUsers: []
                )
            ),

            // Achievement unlock
            ActivityFeedItem(
                id: "2",
                userID: "user2",
                username: "fitnessguru",
                userProfile: UserProfile(
                    id: "user2",
                    userID: "user2",
                    username: "fitnessguru",
                    bio: "Lifting heavy things",
                    workoutCount: 200,
                    totalXP: 67_800,
                    creationDate: Date(),
                    modificationDate: Date(),
                    isVerified: false,
                    privacyLevel: .publicProfile,
                    profileImageURL: nil,
                    headerImageURL: nil
                ),
                type: .achievement,
                timestamp: Date().addingTimeInterval(-7_200),
                content: ActivityFeedContent(
                    title: "Iron Will Unlocked!",
                    subtitle: "Completed 50 strength training sessions",
                    details: [
                        "achievementName": "Iron Will",
                        "achievementIcon": "dumbbell.fill",
                        "xpEarned": "500"
                    ]
                ),
                workoutID: nil,
                kudosCount: 0,
                commentCount: 8,
                hasKudoed: false,
                kudosSummary: nil
            ),

            // Level up
            ActivityFeedItem(
                id: "3",
                userID: "user3",
                username: "yogamaster",
                userProfile: UserProfile(
                    id: "user3",
                    userID: "user3",
                    username: "yogamaster",
                    bio: "Finding balance",
                    workoutCount: 89,
                    totalXP: 28_500,
                    creationDate: Date(),
                    modificationDate: Date(),
                    isVerified: false,
                    privacyLevel: .publicProfile,
                    profileImageURL: nil,
                    headerImageURL: nil
                ),
                type: .levelUp,
                timestamp: Date().addingTimeInterval(-10_800),
                content: ActivityFeedContent(
                    title: "Level 15: Fitness Warrior",
                    subtitle: "Your dedication is inspiring!",
                    details: [
                        "newLevel": "15",
                        "newTitle": "Fitness Warrior"
                    ]
                ),
                workoutID: nil,
                kudosCount: 0,
                commentCount: 15,
                hasKudoed: false,
                kudosSummary: nil
            ),

            // Cycling workout
            ActivityFeedItem(
                id: "4",
                userID: "user4",
                username: "bikerlady",
                userProfile: UserProfile(
                    id: "user4",
                    userID: "user4",
                    username: "bikerlady",
                    bio: "Two wheels, endless roads",
                    workoutCount: 134,
                    totalXP: 52_300,
                    creationDate: Date(),
                    modificationDate: Date(),
                    isVerified: false,
                    privacyLevel: .publicProfile,
                    profileImageURL: nil,
                    headerImageURL: nil
                ),
                type: .workout,
                timestamp: Date().addingTimeInterval(-14_400),
                content: ActivityFeedContent(
                    title: "Evening Ride 🚴‍♀️",
                    subtitle: "Perfect weather for a sunset ride through the hills!",
                    details: [
                        "workoutType": "Cycling",
                        "duration": "3600", // 60 minutes
                        "calories": "580",
                        "xpEarned": "120"
                    ]
                ),
                workoutID: "4",
                kudosCount: 8,
                commentCount: 3,
                hasKudoed: false,
                kudosSummary: WorkoutKudosSummary(
                    workoutID: "4",
                    totalCount: 8,
                    hasUserKudos: false,
                    recentUsers: []
                )
            )
        ]
    }
}

#Preview {
    EnhancedFeedPreview()
}
