//
//  GameMechanicsView.swift
//  FameFit
//
//  Game mechanics explanation - final step of onboarding
//

import SwiftUI

struct GameMechanicsView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var visibleCards: Set<Int> = []
    @State private var showButton = false
    @State private var titleScale: CGFloat = 0.8
    @State private var titleOpacity: Double = 0
    
    let formulaSteps = [
        ("🏋️", "Workouts", "= XP", "Complete any workout", Color.orange),
        ("📈", "XP", "= Status", "Level up your rank", Color.purple),
        ("🏆", "Status", "= Unlocks", "Earn badges & rewards", Color.blue)
    ]
    
    let features = [
        ("📢", "Share for Bonus", "Post workouts for extra fame"),
        ("🌍", "Global Leaderboards", "Compete with everyone"),
        ("🎯", "Achievements", "Unlock badges & bragging rights")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Title section
            VStack(spacing: 12) {
                Text("THE FAME")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .scaleEffect(titleScale)
                    .opacity(titleOpacity)
                
                Text("FORMULA")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(titleScale)
                    .opacity(titleOpacity)
            }
            .padding(.top, 40)
            
            // Formula cards
            ScrollView {
                VStack(spacing: 20) {
                    // Main formula
                    VStack(spacing: 16) {
                        ForEach(Array(formulaSteps.enumerated()), id: \.offset) { index, step in
                            FormulaCard(
                                emoji: step.0,
                                title: step.1,
                                equals: step.2,
                                subtitle: step.3,
                                color: step.4,
                                isVisible: visibleCards.contains(index)
                            )
                        }
                    }
                    .padding(.top, 30)
                    
                    // Additional features
                    if visibleCards.contains(3) {
                        VStack(spacing: 12) {
                            Text("PLUS")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, 10)
                            
                            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                                FeatureRow(
                                    emoji: feature.0,
                                    title: feature.1,
                                    subtitle: feature.2,
                                    isVisible: visibleCards.contains(index + 4)
                                )
                            }
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
            
            Spacer()
            
            // CTA Button
            if showButton {
                VStack(spacing: 16) {
                    Text("Ready to start your influencer journey?")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        Task {
                            await viewModel.completeOnboarding()
                        }
                    }) {
                        HStack {
                            Text("Start Earning XP")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.95)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 0)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    )
                )
            }
        }
        .onAppear {
            animateContent()
        }
        .disabled(viewModel.isLoading)
    }
    
    private func animateContent() {
        // Animate title
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            titleScale = 1.0
            titleOpacity = 1.0
        }
        
        // Animate formula cards
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3 + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    _ = visibleCards.insert(index)
                }
            }
        }
        
        // Show additional features
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                _ = visibleCards.insert(3) // Trigger "PLUS" section
            }
        }
        
        // Animate feature rows
        for index in 0..<features.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.2 + 2.2) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    _ = visibleCards.insert(index + 4)
                }
            }
        }
        
        // Show button
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showButton = true
            }
        }
    }
}

struct FormulaCard: View {
    let emoji: String
    let title: String
    let equals: String
    let subtitle: String
    let color: Color
    let isVisible: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Text(emoji)
                .font(.system(size: 36))
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                )
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(equals)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(color)
                }
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .scaleEffect(isVisible ? 1 : 0.95)
    }
}

struct FeatureRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isVisible: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
        .scaleEffect(isVisible ? 1 : 0.95, anchor: .leading)
    }
}