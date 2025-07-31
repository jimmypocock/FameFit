//
//  ActivityCommentsView.swift
//  FameFit
//
//  Full-screen comments view for any activity type (workouts, achievements, level ups, etc.)
//

import SwiftUI

struct ActivityCommentsView: View {
    let feedItem: FeedItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencyContainer) private var container
    
    @State private var currentUser: UserProfile?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Activity context header
                activityHeader
                
                // Comments list - using the new generic system
                GenericCommentsListView(
                    resourceId: feedItem.id,
                    resourceOwnerId: feedItem.userID,
                    resourceType: getResourceType(for: feedItem.type),
                    sourceRecordId: feedItem.workoutId, // For workouts, this is the workout ID
                    currentUser: currentUser,
                    commentService: getCommentService(for: feedItem.type)
                )
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            // Share activity
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            // Report inappropriate content
                        }) {
                            Label("Report", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadCurrentUser()
        }
    }
    
    // MARK: - Activity Header
    
    private var activityHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Activity owner profile
                if let userProfile = feedItem.userProfile {
                    AsyncImage(url: userProfile.profileImageURL.flatMap { URL(string: $0) }) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                Text(userProfile.username.prefix(1))
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.blue)
                            )
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(userProfile.username)
                                .font(.system(size: 16, weight: .semibold))
                            
                            if userProfile.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text("@\(userProfile.username)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Activity time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(feedItem.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Activity summary based on type
            activitySummary
        }
        .padding(16)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var activitySummary: some View {
        switch feedItem.type {
        case .workout:
            workoutSummary
        case .achievement:
            achievementSummary
        case .levelUp:
            levelUpSummary
        case .milestone:
            milestoneSummary
        case .challenge:
            challengeSummary
        case .groupWorkout:
            groupWorkoutSummary
        }
    }
    
    private var workoutSummary: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: workoutIcon(for: feedItem.content.workoutType ?? ""))
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text(feedItem.content.workoutType ?? "Workout")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Spacer()
                
                if let xp = feedItem.content.xpEarned {
                    Text("+\(xp) XP")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            
            // Quick stats
            HStack(spacing: 16) {
                if let duration = feedItem.content.duration {
                    StatPill(
                        icon: "clock",
                        value: formatDuration(duration),
                        color: .orange
                    )
                }
                
                if let calories = feedItem.content.calories {
                    StatPill(
                        icon: "flame",
                        value: "\(Int(calories)) cal",
                        color: .red
                    )
                }
                
                if let distance = feedItem.content.details["distance"],
                   let distanceValue = Double(distance) {
                    StatPill(
                        icon: "location",
                        value: formatDistance(distanceValue),
                        color: .blue
                    )
                }
            }
        }
    }
    
    private var achievementSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Achievement Unlocked")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(feedItem.content.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
    
    private var levelUpSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.purple)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Level Up!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(feedItem.content.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
    
    private var milestoneSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Milestone Reached")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(feedItem.content.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
    
    private var challengeSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 32))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Challenge")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(feedItem.content.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
    
    private var groupWorkoutSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Group Workout")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(feedItem.content.title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
    
    
    // MARK: - Helper Views
    
    private struct StatPill: View {
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
    
    // MARK: - Helper Methods
    
    private func workoutIcon(for type: String) -> String {
        switch type.lowercased() {
        case "running":
            "figure.run"
        case "cycling":
            "bicycle"
        case "swimming":
            "figure.pool.swim"
        case "walking":
            "figure.walk"
        case "hiking":
            "figure.hiking"
        case "yoga":
            "figure.yoga"
        case "strength training", "functional strength training", "traditional strength training":
            "dumbbell"
        default:
            "figure.mixed.cardio"
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let kilometers = meters / 1000
        if kilometers >= 1 {
            return String(format: "%.1f km", kilometers)
        } else {
            return "\(Int(meters)) m"
        }
    }
    
    private func loadCurrentUser() {
        Task {
            do {
                if let userId = container.cloudKitManager.currentUserID {
                    currentUser = try await container.userProfileService.fetchProfile(userId: userId)
                }
            } catch {
                print("Failed to load current user: \(error)")
            }
        }
    }
    
    private func getResourceType(for feedItemType: FeedItemType) -> String {
        switch feedItemType {
        case .workout:
            return "workout"
        case .achievement:
            return "achievement"
        case .levelUp:
            return "level_up"
        case .milestone:
            return "milestone"
        case .challenge:
            return "challenge"
        case .groupWorkout:
            return "group_workout"
        }
    }
    
    private func getCommentService(for feedItemType: FeedItemType) -> AnyCommentService {
        // Always use ActivityCommentsService for consistency
        // This ensures all comments go to the same table regardless of activity type
        let adapter = ActivityCommentsAdapter(activityCommentsService: container.activityCommentsService)
        return AnyCommentService(adapter)
    }
}

// MARK: - Preview

#Preview {
    // Create a preview with the actual FeedItem structure used in ActivityFeedView
    ActivityCommentsView(
        feedItem: FeedItem(
            id: "test-feed-item",
            userID: "user123",
            userProfile: UserProfile(
                id: "user123",
                userID: "user123",
                username: "runner_sam",
                bio: "Marathon enthusiast",
                workoutCount: 312,
                totalXP: 12500,
                createdTimestamp: Date().addingTimeInterval(-86400 * 500),
                modifiedTimestamp: Date(),
                isVerified: true,
                privacyLevel: .publicProfile,
                profileImageURL: nil
            ),
            type: .workout,
            timestamp: Date().addingTimeInterval(-3600),
            content: FeedContent(
                title: "Morning Run",
                subtitle: "Great workout!",
                details: [
                    "workoutType": "Running",
                    "duration": "3600",
                    "calories": "450",
                    "distance": "8000",
                    "xpEarned": "25"
                ]
            ),
            workoutId: "test-workout-id",
            kudosCount: 5,
            commentCount: 3,
            hasKudoed: false
        )
    )
}