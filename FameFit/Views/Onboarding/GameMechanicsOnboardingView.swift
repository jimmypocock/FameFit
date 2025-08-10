//
//  GameMechanicsOnboardingView.swift
//  FameFit
//
//  Game mechanics explanation - final onboarding step
//

import SwiftUI

struct GameMechanicsOnboardingView: View {
    @Binding var onboardingStep: Int
    @State private var visibleMessages = 0
    @State private var showContinueButton = false
    @State private var isCompletingOnboarding = false
    @EnvironmentObject var authManager: AuthenticationService
    @Environment(\.dependencyContainer) var container
    
    struct ChatMessage {
        let speaker: String
        let emoji: String
        let message: String
        let color: Color
    }

    let messages = [
        ChatMessage(speaker: "Chad", emoji: "💪", message: "Alright rookie, time to learn how this works! Every workout you do earns you XP - that's Experience Points for the noobs.", color: .red),
        ChatMessage(speaker: "Sierra", emoji: "🏃‍♀️", message: "The harder you work, the more XP you earn! I personally aim for at least 1000 XP per workout. Anything less is just cardio.", color: .orange),
        ChatMessage(speaker: "Zen", emoji: "🧘‍♂️", message: "As your XP grows, so does your influence. You'll unlock new titles like 'Mindful Warrior' or 'Zen Master'. The universe rewards consistency.", color: .green),
        ChatMessage(speaker: "Chad", emoji: "💪", message: "Plus, you can follow other users, join group workouts, and climb the leaderboards! Competition is the best pre-workout!", color: .red),
        ChatMessage(speaker: "Sierra", emoji: "🏃‍♀️", message: "And don't forget about challenges! Beat them to earn bonus XP and show everyone who's boss. I haven't lost one yet!", color: .orange),
        ChatMessage(speaker: "Zen", emoji: "🧘‍♂️", message: "Remember, this journey is about more than numbers. It's about becoming the best version of yourself... with the most followers.", color: .green),
        ChatMessage(speaker: "Chad", emoji: "💪", message: "That's enough talk! Time to start sweating and earning that XP! LET'S GO!", color: .red)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("HOW IT WORKS")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.top)
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<visibleMessages, id: \.self) { index in
                            GameChatBubble(message: messages[index])
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
                    completeOnboardingWithVerification()
                }) {
                    Text("Let's Get Started!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .disabled(isCompletingOnboarding)
        .overlay {
            if isCompletingOnboarding {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(.white)
                    Text("Setting up your account...")
                        .foregroundColor(.white)
                }
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
    
    private func completeOnboardingWithVerification() {
        isCompletingOnboarding = true
        
        Task {
            do {
                // Verify profile exists before completing onboarding
                print("🎮 GameMechanics: Verifying profile exists...")
                _ = try await container.userProfileService.fetchCurrentUserProfile()
                
                // Profile exists, safe to complete onboarding
                print("🎮 GameMechanics: Profile verified, completing onboarding...")
                await MainActor.run {
                    authManager.completeOnboarding()
                    
                    // Now that onboarding is complete, start health services
                    container.workoutObserver.startObservingWorkouts()
                    container.workoutAutoShareService.setupAutoSharing()
                    
                    isCompletingOnboarding = false
                }
            } catch {
                print("🎮 GameMechanics: Profile not found, cannot complete onboarding")
                await MainActor.run {
                    isCompletingOnboarding = false
                    // Go back to profile creation
                    onboardingStep = 3
                }
            }
        }
    }
}

struct GameChatBubble: View {
    let message: GameMechanicsOnboardingView.ChatMessage
    
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
        
        GameMechanicsOnboardingView(onboardingStep: .constant(4))
            .environmentObject(AuthenticationService(cloudKitManager: CloudKitService()))
    }
}
