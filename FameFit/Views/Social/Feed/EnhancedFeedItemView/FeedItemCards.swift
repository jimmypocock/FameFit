//
//  ActivityFeedItemCards.swift
//  FameFit
//
//  Additional card components for different feed item types
//

import SwiftUI

// MARK: - Achievement Card

struct EnhancedAchievementCard: View {
    let item: ActivityFeedItem
    let onProfileTap: () -> Void
    @Binding var showCelebration: Bool

    var body: some View {
        VStack(spacing: 16) {
            // User Header
            HStack(spacing: 12) {
                Button(action: onProfileTap) {
                    ProfileImageView(profile: item.userProfile)
                        .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.userProfile?.username ?? "Unknown")
                        .font(.body)
                        .fontWeight(.medium)

                    Text(item.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Achievement Content
            ZStack {
                LinearGradient(
                    colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 8) {
                    Text("🏆")
                        .font(.system(size: 48))

                    Text(item.content.title)
                        .font(.headline)

                    if let subtitle = item.content.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            showCelebration = true
        }
    }
}

// MARK: - Level Up Card

struct EnhancedLevelUpCard: View {
    let item: ActivityFeedItem
    let onProfileTap: () -> Void

    @State private var animate = false

    var body: some View {
        VStack(spacing: 16) {
            // User Header
            HStack(spacing: 12) {
                Button(action: onProfileTap) {
                    ProfileImageView(profile: item.userProfile)
                        .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.userProfile?.username ?? "Unknown")
                        .font(.body)
                        .fontWeight(.medium)

                    Text(item.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Level Up Content
            ZStack {
                LinearGradient(
                    colors: [Color.purple, Color.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 12) {
                    Text("⭐")
                        .font(.system(size: 48))
                        .scaleEffect(animate ? 1.2 : 1.0)

                    Text(item.content.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if let subtitle = item.content.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Milestone Card

struct EnhancedMilestoneCard: View {
    let item: ActivityFeedItem
    let onProfileTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // User Header
            HStack(spacing: 12) {
                Button(action: onProfileTap) {
                    ProfileImageView(profile: item.userProfile)
                        .frame(width: 40, height: 40)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.userProfile?.username ?? "Unknown")
                        .font(.body)
                        .fontWeight(.medium)

                    Text(item.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Milestone Content
            ZStack {
                LinearGradient(
                    colors: [Color.green.opacity(0.3), Color.blue.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 8) {
                    Text("🎯")
                        .font(.system(size: 40))

                    Text(item.content.title)
                        .font(.headline)

                    if let subtitle = item.content.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Quick Reactions View

struct QuickReactionsView: View {
    let onReaction: (String) -> Void
    @State private var selectedReaction: String?

    let reactions = ["💪", "🔥", "👏", "❤️"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions, id: \.self) { emoji in
                Button(action: {
                    selectedReaction = emoji
                    onReaction(emoji)

                    // Reset after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        selectedReaction = nil
                    }
                }) {
                    Text(emoji)
                        .font(.title3)
                        .scaleEffect(selectedReaction == emoji ? 1.5 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedReaction)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}