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
                // Profile image removed for now
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(item.username.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                    .onTapGesture {
                        onProfileTap()
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.username)
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
                // Profile image removed for now
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(item.username.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                    .onTapGesture {
                        onProfileTap()
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.username)
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
                // Profile image removed for now
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(item.username.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                    .onTapGesture {
                        onProfileTap()
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.username)
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

