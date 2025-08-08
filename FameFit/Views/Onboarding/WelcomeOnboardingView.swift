//
//  WelcomeOnboardingView.swift
//  FameFit
//
//  Welcome screen with character introductions
//

import SwiftUI

struct WelcomeOnboardingView: View {
    @Binding var onboardingStep: Int
    @State private var visibleMessages = 0
    @State private var showContinueButton = false
    
    struct ChatMessage {
        let speaker: String
        let emoji: String
        let message: String
        let color: Color
        let isUser: Bool = false
    }

    let messages = [
        ChatMessage(speaker: "Chad", emoji: "💪", message: "Yo! Welcome to FameFit! I'm Chad Maximus, and these are my... coworkers.", color: .red),
        ChatMessage(speaker: "Sierra", emoji: "🏃‍♀️", message: "Business partners, Chad. We're business partners. Anyway, I'm Sierra Pace, and fun fact: I've already burned 47 calories just standing here!", color: .orange),
        ChatMessage(speaker: "Zen", emoji: "🧘‍♂️", message: "And I'm Zen Flexington, here to align your chakras and your follower count. Deep breath in... and exhale those amateur fitness vibes.", color: .green),
        ChatMessage(speaker: "Chad", emoji: "💪", message: "Listen up! We're the top fitness influencers at FameFit, and we're here to make YOU Insta-famous!", color: .red),
        ChatMessage(speaker: "Sierra", emoji: "🏃‍♀️", message: "Because let's be real - working out without posting about it is just... sweating for free.", color: .orange),
        ChatMessage(speaker: "Zen", emoji: "🧘‍♂️", message: "The universe has brought you here to manifest your destiny. And by universe, I mean the algorithm.", color: .green),
        ChatMessage(speaker: "Chad", emoji: "💪", message: "Let's get you started by making sure we can see your gains.", color: .red)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("FAMEFIT")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.top)
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<visibleMessages, id: \.self) { index in
                            WelcomeChatBubble(message: messages[index])
                                .id(index)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .identity
                                ))
                        }
                        
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                }
                .onChange(of: visibleMessages) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Continue button
            if showContinueButton {
                Button(action: {
                    withAnimation {
                        onboardingStep = 1
                    }
                }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(15)
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            animateMessages()
        }
    }
    
    func animateMessages() {
        for index in 0..<messages.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    visibleMessages = index + 1
                }
                
                // Show continue button after last message
                if index == messages.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            showContinueButton = true
                        }
                    }
                }
            }
        }
    }
}

struct WelcomeChatBubble: View {
    let message: WelcomeOnboardingView.ChatMessage
    
    var body: some View {
        HStack {
            if message.speaker == "Sierra" || message.speaker == "Zen" {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.speaker == "Chad" ? .leading : .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    if message.speaker == "Chad" {
                        Text(message.emoji)
                            .font(.title2)
                    }
                    
                    Text(message.speaker)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.8))
                    
                    if message.speaker != "Chad" {
                        Text(message.emoji)
                            .font(.title2)
                    }
                }
                
                Text(message.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(message.color.opacity(0.8))
                    .cornerRadius(16, corners: message.speaker == "Chad" ? [.topRight, .bottomLeft, .bottomRight] : [.topLeft, .bottomLeft, .bottomRight])
            }
            
            if message.speaker == "Chad" {
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.purple, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        WelcomeOnboardingView(onboardingStep: .constant(0))
    }
}
