//
//  CelebrationEffects.swift
//  FameFit
//
//  Celebration animations for achievements and milestones
//

import SwiftUI

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var animate = false
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]

    var body: some View {
        ZStack {
            ForEach(0 ..< 50) { index in
                ConfettiPiece(
                    color: colors[index % colors.count],
                    size: CGFloat.random(in: 4 ... 8),
                    delay: Double.random(in: 0 ... 0.5),
                    animate: $animate
                )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let size: CGFloat
    let delay: Double
    @Binding var animate: Bool

    @State private var offsetX = CGFloat.random(in: -150 ... 150)
    @State private var offsetY = CGFloat.random(in: -50 ... 50)
    @State private var rotation = Double.random(in: 0 ... 360)

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: size, height: size * 2)
            .offset(x: animate ? offsetX : 0, y: animate ? offsetY + 600 : -50)
            .rotationEffect(.degrees(animate ? rotation + 360 : rotation))
            .opacity(animate ? 0 : 1)
            .animation(
                .easeOut(duration: 3)
                    .delay(delay),
                value: animate
            )
    }
}

// MARK: - Streak Fire Animation

struct StreakFireView: View {
    let streakDays: Int
    @State private var animate = false

    var flameSize: CGFloat {
        min(20 + CGFloat(streakDays) * 2, 60)
    }

    var body: some View {
        ZStack {
            // Base flame
            Image(systemName: "flame.fill")
                .font(.system(size: flameSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .scaleEffect(animate ? 1.1 : 0.9)
                .animation(
                    .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true),
                    value: animate
                )

            // Inner flame
            Image(systemName: "flame.fill")
                .font(.system(size: flameSize * 0.6))
                .foregroundColor(.yellow)
                .offset(y: flameSize * 0.1)
                .scaleEffect(animate ? 0.9 : 1.1)
                .animation(
                    .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true),
                    value: animate
                )

            // Streak number
            if streakDays > 1 {
                Text("\(streakDays)")
                    .font(.system(size: flameSize * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .offset(y: flameSize * 0.2)
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Level Up Animation

struct LevelUpAnimationView: View {
    let level: Int
    let title: String
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            // Animated star burst
            ZStack {
                ForEach(0 ..< 8) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 100)
                        .offset(y: -50)
                        .rotationEffect(.degrees(Double(index) * 45 + rotation))
                        .opacity(opacity)
                }
            }
            .frame(width: 200, height: 200)

            // Level badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    Text("LEVEL")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))

                    Text("\(level)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(scale)

            // Title
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1
                opacity = 1
            }

            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            // Fade out after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0
                    scale = 0.8
                }
            }
        }
    }
}

// MARK: - Quick Reaction Animation

struct QuickReactionAnimationView: View {
    let emoji: String
    let startPosition: CGPoint
    @State private var offset = CGSize.zero
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1

    var body: some View {
        Text(emoji)
            .font(.system(size: 40))
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
            .position(startPosition)
            .onAppear {
                withAnimation(.easeOut(duration: 2)) {
                    offset = CGSize(
                        width: CGFloat.random(in: -50 ... 50),
                        height: -200
                    )
                    opacity = 0
                }

                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.5
                }

                withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
                    scale = 1
                }
            }
    }
}

// MARK: - Floating Hearts Animation

struct FloatingHeartsView: View {
    @State private var hearts: [(id: UUID, position: CGPoint)] = []
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ForEach(hearts, id: \.id) { heart in
                FloatingHeart(startPosition: heart.position)
            }
        }
        .onReceive(timer) { _ in
            let newHeart = (
                id: UUID(),
                position: CGPoint(
                    x: CGFloat.random(in: 50 ... UIScreen.main.bounds.width - 50),
                    y: UIScreen.main.bounds.height - 100
                )
            )
            hearts.append(newHeart)

            // Remove old hearts
            if hearts.count > 20 {
                hearts.removeFirst()
            }
        }
    }
}

struct FloatingHeart: View {
    let startPosition: CGPoint
    @State private var offset = CGSize.zero
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 0

    var body: some View {
        Image(systemName: "heart.fill")
            .foregroundColor(.red)
            .font(.title)
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
            .position(startPosition)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1
                }

                withAnimation(.easeOut(duration: 3)) {
                    offset = CGSize(
                        width: CGFloat.random(in: -30 ... 30),
                        height: -300
                    )
                    opacity = 0
                }
            }
    }
}

// MARK: - Progress Ring Animation

struct ProgressRingAnimationView: View {
    let progress: Double
    let color: Color
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: 8,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 1.5), value: animatedProgress)

            // Center pulse effect
            Circle()
                .fill(color.opacity(0.2))
                .scaleEffect(animatedProgress)
                .animation(
                    .easeOut(duration: 1.5)
                        .repeatCount(1, autoreverses: true),
                    value: animatedProgress
                )
        }
        .frame(width: 100, height: 100)
        .onAppear {
            animatedProgress = progress
        }
    }
}
