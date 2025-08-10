//
//  WelcomeView.swift
//  FameFit
//
//  Welcome step of onboarding - introduces the app concept
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var visibleLines: Set<Int> = []
    @State private var showButton = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    
    let messages = [
        ("Welcome to FameFit!", 0.3),
        ("The only app where", 0.8),
        ("gains get you fame", 1.3),
        ("Turn sweat into social currency", 2.1),
        ("Every workout earns XP", 2.9),
        ("Climb from Fitness Newbie", 3.7),
        ("to Verified Legend", 4.2),
        ("Because working out without XP?", 5.2),
        ("That's just exercise.", 5.8)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo section
            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Text("FAMEFIT")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Animated messages
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                    MessageLine(
                        text: message.0,
                        index: index,
                        isVisible: visibleLines.contains(index),
                        isMainMessage: index == 0 || index == 2 || index == 8
                    )
                }
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            // Sign in section
            if showButton {
                VStack(spacing: 20) {
                    Text("Let's get you set up with an account so we can track your journey to fitness fame!")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                    
                    SignInWithAppleButton()
                        .frame(height: 50)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    )
                )
            }
        }
        .onAppear {
            animateContent()
        }
    }
    
    private func animateContent() {
        // Animate logo
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Animate each message line
        for (index, message) in messages.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + message.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    _ = visibleLines.insert(index)
                }
            }
        }
        
        // Show button after all messages
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.8) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showButton = true
            }
        }
    }
}

struct MessageLine: View {
    let text: String
    let index: Int
    let isVisible: Bool
    let isMainMessage: Bool
    
    var body: some View {
        Text(text)
            .font(.system(
                size: isMainMessage ? 28 : 22,
                weight: isMainMessage ? .black : .semibold,
                design: .rounded
            ))
            .foregroundColor(
                isMainMessage ? .white : .white.opacity(0.85)
            )
            .opacity(isVisible ? 1 : 0)
            .offset(x: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1 : 0.9, anchor: .leading)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8),
                value: isVisible
            )
    }
}
