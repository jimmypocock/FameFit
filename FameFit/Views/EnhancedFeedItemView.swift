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
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Enhanced Workout Card

struct EnhancedWorkoutCard: View {
    let item: FeedItem
    let onProfileTap: () -> Void
    let onKudosTap: (FeedItem) async -> Void
    let onCommentsTap: (FeedItem) -> Void
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
                        Button(action: onProfileTap) {
                            ProfileImageView(profile: item.userProfile)
                                .frame(width: 44, height: 44)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(item.userProfile?.displayName ?? "Unknown")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                if item.userProfile?.isVerified == true {
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
                                progress: min(calories / 500, 1.0), // 500 cal max
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

                    // Comments Button
                    Button(action: { onCommentsTap(item) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left")
                                .foregroundColor(.secondary)

                            if item.commentCount > 0 {
                                Text("\(item.commentCount)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                    }

                    Spacer()

                    // Quick Reactions
                    QuickReactionsView { _ in
                        // Handle quick reaction
                        Task {
                            showKudosAnimation = true
                            await onKudosTap(item)
                        }
                    }
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

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let value: String
    let label: String
    let color: Color
    @Binding var animate: Bool

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 6)
                .frame(width: 70, height: 70)

            // Progress circle
            Circle()
                .trim(from: 0, to: animate ? progress : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.2), value: animate)

            // Value
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Supporting Views

struct ProfileImageView: View {
    let profile: UserProfile?

    var body: some View {
        if let profile, profile.profileImageURL != nil {
            // TODO: AsyncImage when implemented
            Circle()
                .fill(Color.gray.opacity(0.3))
        } else if let profile {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Text(profile.initials)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                )
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
        }
    }
}

struct PRBadge: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            Text("🏆")
            Text("NEW PR!")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.yellow.opacity(0.2))
        )
        .scaleEffect(animate ? 1.1 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct XPBadge: View {
    let xp: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption)
                .foregroundColor(.yellow)
            Text("+\(xp) XP")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.yellow.opacity(0.15))
        )
    }
}

struct CharacterCommentary: View {
    let text: String
    let workoutType: String

    var characterColor: Color {
        // Different characters for different workout types
        switch workoutType.lowercased() {
        case "running", "run": .orange
        case "cycling", "bike": .purple
        case "swimming", "swim": .blue
        case "strength", "weight": .pink
        default: .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(characterColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(characterEmoji)
                        .font(.system(size: 16))
                )

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private var characterEmoji: String {
        switch workoutType.lowercased() {
        case "running", "run": "🏃"
        case "cycling", "bike": "🚴"
        case "swimming", "swim": "🏊"
        case "strength", "weight": "💪"
        default: "🤸"
        }
    }
}

struct FloatingKudosView: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        ZStack {
            ForEach(0 ..< 3) { index in
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.title)
                    .offset(
                        x: CGFloat.random(in: -20 ... 20),
                        y: offset - CGFloat(index * 20)
                    )
                    .opacity(opacity)
                    .rotationEffect(.degrees(Double.random(in: -20 ... 20)))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                offset = -100
                opacity = 0
            }
        }
    }
}

// MARK: - Enhanced Achievement Card

struct EnhancedAchievementCard: View {
    let item: FeedItem
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
                    Text(item.userProfile?.displayName ?? "Unknown")
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

// MARK: - Enhanced Level Up Card

struct EnhancedLevelUpCard: View {
    let item: FeedItem
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
                    Text(item.userProfile?.displayName ?? "Unknown")
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
                    Text("LEVEL UP!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .scaleEffect(animate ? 1.1 : 1.0)

                    Text(item.content.title)
                        .font(.title2)
                        .fontWeight(.semibold)
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
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Enhanced Milestone Card

struct EnhancedMilestoneCard: View {
    let item: FeedItem
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
                    Text(item.userProfile?.displayName ?? "Unknown")
                        .font(.body)
                        .fontWeight(.medium)

                    Text(item.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Milestone Content
            HStack(spacing: 16) {
                Image(systemName: "flag.checkered")
                    .font(.largeTitle)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.content.title)
                        .font(.headline)

                    if let subtitle = item.content.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(0.1))
            )
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
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
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
