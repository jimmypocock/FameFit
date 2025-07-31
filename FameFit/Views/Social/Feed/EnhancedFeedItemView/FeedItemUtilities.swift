//
//  FeedItemUtilities.swift
//  FameFit
//
//  Utility components for feed items
//

import SwiftUI

// MARK: - Progress View

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

// MARK: - Profile Image

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

// MARK: - Badges

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

// MARK: - Character Commentary

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

// MARK: - Animations

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