//
//  EnhancedWorkoutCard.swift
//  FameFit
//
//  Enhanced workout card with animations and rich visual design
//

import SwiftUI

struct EnhancedWorkoutCard: View {
    let item: ActivityFeedItem
    let onProfileTap: () -> Void
    let onKudosTap: (ActivityFeedItem) async -> Void
    let onCommentsTap: (ActivityFeedItem) -> Void
    @Binding var showKudosAnimation: Bool
    @Binding var kudosScale: CGFloat

    @State private var animateProgress = false

    var workoutGradient: LinearGradient {
        switch item.content.workoutType?.lowercased() {
        case "running", "run":
            LinearGradient(
                colors: [Color(hex: "FF6B6B"), Color(hex: "4ECDC4")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "cycling", "bike":
            LinearGradient(
                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "swimming", "swim":
            LinearGradient(
                colors: [Color(hex: "2193B0"), Color(hex: "6DD5ED")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "strength", "weight":
            LinearGradient(
                colors: [Color(hex: "F093FB"), Color(hex: "F5576C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            LinearGradient(
                colors: [Color(hex: "A8E063"), Color(hex: "56AB2F")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hero Section with Gradient
            ZStack {
                workoutGradient
                    .frame(height: 180)

                // Floating workout stats
                VStack(spacing: 16) {
                    // User header
                    HStack(spacing: 12) {
                        // Profile image removed for now
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(item.username.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            )
                            .onTapGesture {
                                onProfileTap()
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.username)
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                if item.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.white.opacity(0.9))
                                        .font(.caption)
                                }
                            }

                            Text(item.timeAgo)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()

                        // Workout type icon
                        Image(systemName: workoutIcon)
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    Spacer()

                    // Animated Progress Rings
                    HStack(spacing: 24) {
                        if let duration = item.content.duration {
                            CircularProgressView(
                                progress: min(duration / 3_600, 1.0), // 1 hour max
                                value: formatDuration(duration),
                                label: "Time",
                                color: .white,
                                animate: $animateProgress
                            )
                        }

                        if let calories = item.content.calories {
                            CircularProgressView(
                                progress: min(Double(calories) / 500, 1.0), // 500 cal max
                                value: "\(Int(calories))",
                                label: "Cal",
                                color: .white,
                                animate: $animateProgress
                            )
                        }

                        if let xp = item.content.xpEarned {
                            CircularProgressView(
                                progress: min(Double(xp) / 100, 1.0), // 100 XP max
                                value: "+\(xp)",
                                label: "XP",
                                color: .white,
                                animate: $animateProgress
                            )
                        }
                    }
                    .padding(.bottom)
                }
            }

            // Content Section
            VStack(alignment: .leading, spacing: 16) {
                // Title with PR badge
                HStack {
                    Text(item.content.title)
                        .font(.headline)

                    if item.content.subtitle?.contains("Personal Record") == true {
                        PRBadge()
                    }

                    Spacer()

                    if let xp = item.content.xpEarned {
                        XPBadge(xp: xp)
                    }
                }

                // Character Commentary
                if let subtitle = item.content.subtitle {
                    CharacterCommentary(
                        text: subtitle,
                        workoutType: item.content.workoutType ?? ""
                    )
                }

                // Social Actions
                HStack(spacing: 16) {
                    // Enhanced Kudos Button
                    Button(action: {
                        Task {
                            showKudosAnimation = true
                            kudosScale = 1.3
                            await onKudosTap(item)

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                kudosScale = 1.0
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: item.kudosSummary?.hasUserKudos == true ? "flame.fill" : "flame")
                                .foregroundColor(item.kudosSummary?.hasUserKudos == true ? .orange : .secondary)
                                .scaleEffect(kudosScale)

                            if let kudosSummary = item.kudosSummary, kudosSummary.totalCount > 0 {
                                Text("\(kudosSummary.totalCount)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(item.kudosSummary?.hasUserKudos == true ? Color.orange.opacity(0.15) : Color
                                    .secondary.opacity(0.1)
                                )
                        )
                    }

                    // Comments removed for now

                    Spacer()
                }
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animateProgress = true
            }
        }
        .overlay(
            // Floating kudos animation
            showKudosAnimation ? FloatingKudosView() : nil
        )
    }

    private var workoutIcon: String {
        switch item.content.workoutType?.lowercased() {
        case "running", "run": "figure.run"
        case "cycling", "bike": "bicycle"
        case "swimming", "swim": "figure.pool.swim"
        case "strength", "weight": "dumbbell.fill"
        default: "figure.walk"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
