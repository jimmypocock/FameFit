import HealthKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var workoutObserver: WorkoutObserver
    @Environment(\.dependencyContainer) var container

    @State private var onboardingStep = 0
    @State private var showSignIn = false
    @State private var healthKitAuthorized = false
    @State private var showProfileCreation = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                switch onboardingStep {
                case 0:
                    WelcomeView(onboardingStep: $onboardingStep)
                case 1:
                    SignInView(onboardingStep: $onboardingStep, showSignIn: $showSignIn)
                case 2:
                    HealthKitPermissionView(onboardingStep: $onboardingStep, healthKitAuthorized: $healthKitAuthorized)
                case 3:
                    ProfileSetupView(onboardingStep: $onboardingStep, showProfileCreation: $showProfileCreation)
                case 4:
                    GameMechanicsView(onboardingStep: $onboardingStep)
                default:
                    Text("Welcome to FameFit!")
                }
            }
            .padding()
        }
        .sheet(isPresented: $showProfileCreation) {
            ProfileCreationView()
                .interactiveDismissDisabled()
                .onDisappear {
                    // Move to next step after profile creation
                    onboardingStep = 4
                }
        }
        .onAppear {
            // If user is already authenticated, skip to the appropriate step
            if authManager.isAuthenticated {
                // Skip to HealthKit permissions step
                onboardingStep = 2
            }
        }
    }
}

struct WelcomeView: View {
    @Binding var onboardingStep: Int
    @State private var displayedMessages: [ConversationMessage] = []
    @State private var conversationComplete = false

    let dialogues = [
        ("Chad", "💪", "Yo! Welcome to FameFit! I'm Chad Maximus, and these are my... coworkers.", Color.red),
        (
            "Sierra",
            "🏃‍♀️",
            "Business partners, Chad. We're business partners. Anyway, I'm Sierra Pace, " +
                "and fun fact: I've already burned 47 calories just standing here!",
            Color.orange
        ),
        (
            "Zen",
            "🧘‍♂️",
            "And I'm Zen Flexington, here to align your chakras and your follower count. " +
                "Deep breath in... and exhale those amateur fitness vibes.",
            Color.green
        ),
        (
            "Chad",
            "💪",
            "Listen up! We're the top fitness influencers at FameFit, " +
                "and we're here to make YOU Insta-famous!",
            Color.red
        ),
        (
            "Sierra",
            "🏃‍♀️",
            "Because let's be real - working out without posting about it " +
                "is just... sweating for free.",
            Color.orange
        ),
        (
            "Zen",
            "🧘‍♂️",
            "The universe has brought you here to manifest your destiny. " +
                "And by universe, I mean the algorithm.",
            Color.green
        ),
        ("Chad", "💪", "Let's get you started by making sure we can see your gains.", Color.red)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("FAMEFIT")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

            // Scrollable conversation
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(Array(displayedMessages.enumerated()), id: \.offset) { index, message in
                            ConversationBubbleView(message: message)
                                .id(index)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 400)
                .onChange(of: displayedMessages.count) { _, newCount in
                    if newCount > 0 {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
            }

            Spacer()

            // Show button only when conversation is complete
            if conversationComplete {
                Button(action: {
                    onboardingStep = 1
                }, label: {
                    Text("Let's Go!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(15)
                })
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            startConversation()
        }
    }
    
    private func startConversation() {
        // Reset state
        displayedMessages = []
        conversationComplete = false
        
        // Start adding messages with delays
        for (index, dialogue) in dialogues.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2.0) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    displayedMessages.append(ConversationMessage(
                        name: dialogue.0,
                        emoji: dialogue.1,
                        message: dialogue.2,
                        color: dialogue.3
                    ))
                }
                
                // Mark conversation complete after last message
                if index == dialogues.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                            conversationComplete = true
                        }
                    }
                }
            }
        }
    }
}

struct ConversationMessage {
    let name: String
    let emoji: String
    let message: String
    let color: Color
}

struct ConversationBubbleView: View {
    let message: ConversationMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Character avatar
            VStack {
                Text(message.emoji)
                    .font(.system(size: 40))
                Text(message.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(width: 60)
            
            // Message bubble
            VStack(alignment: .leading, spacing: 4) {
                Text(message.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(message.color.opacity(0.3))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(message.color.opacity(0.5), lineWidth: 1)
            )
            
            Spacer()
        }
    }
}

struct SignInView: View {
    @Binding var onboardingStep: Int
    @Binding var showSignIn: Bool
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 30) {
            Text("SIGN IN")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text("First, let's get you set up with an account so we can track your journey to fitness fame!")
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Spacer()

            SignInWithAppleButton()
                .frame(height: 50)
                .cornerRadius(10)

            Spacer()
        }
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                onboardingStep = 2
            }
        }
    }
}

struct HealthKitPermissionView: View {
    @Binding var onboardingStep: Int
    @Binding var healthKitAuthorized: Bool
    @EnvironmentObject var workoutObserver: WorkoutObserver

    var body: some View {
        VStack(spacing: 30) {
            Text("PERMISSIONS")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("We need access to your workouts to track your fitness journey!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(
                    "This lets us:\n• Detect when you complete workouts\n• Track your progress\n• Award you Influencer XP for your efforts"
                )
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(20)

            Spacer()

            Button(action: {
                workoutObserver.requestHealthKitAuthorization { success, _ in
                    if success {
                        healthKitAuthorized = true
                        onboardingStep = 3
                    }
                }
            }, label: {
                Text("Grant Access")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(15)
            })

            if healthKitAuthorized {
                Text("✅ Access Granted!")
                    .foregroundColor(.green)
                    .font(.headline)
            }
        }
    }
}

struct ProfileSetupView: View {
    @Binding var onboardingStep: Int
    @Binding var showProfileCreation: Bool
    @Environment(\.dependencyContainer) var container

    var body: some View {
        VStack(spacing: 30) {
            Text("CREATE YOUR PROFILE")
                .font(.system(size: 35, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                Text("Let's set up your fitness profile!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Choose a unique username, add a profile photo, and tell us about your fitness journey.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button(action: {
                showProfileCreation = true
            }, label: {
                Text("Create Profile")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(15)
            })
        }
        .task {
            // Check if user already has a profile
            do {
                _ = try await container.userProfileService.fetchCurrentUserProfile()
                // Profile exists, skip to next step
                onboardingStep = 4
            } catch {
                // No profile, stay on this step
            }
        }
    }
}

struct GameMechanicsView: View {
    @Binding var onboardingStep: Int
    @State private var displayedMessages: [ConversationMessage] = []
    @State private var conversationComplete = false
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dependencyContainer) var container

    let dialogues = [
        ("Chad", "💪", "Perfect. Now, here's the deal: Every workout you crush earns you Influencer XP.", Color.red),
        (
            "Sierra",
            "🏃‍♀️",
            "And more XP means SPONSORSHIPS! I'm talking free protein powder, " +
                "workout gear, and those weird teas nobody actually drinks!",
            Color.orange
        ),
        (
            "Zen",
            "🧘‍♂️",
            "And don't forget the exclusive events. Last week I did yoga with " +
                "a B-list celebrity's personal assistant's dog walker. Networking!",
            Color.green
        ),
        (
            "Chad",
            "💪",
            "Plus, once you hit certain follower milestones, you unlock the VIP stuff - " +
                "celebrity gym parties, influencer retreats...",
            Color.red
        ),
        ("Sierra", "🏃‍♀️", "...5K runs with people who actually care about your split times...", Color.orange),
        ("Zen", "🧘‍♂️", "...and meditation sessions where we collectively manifest verified checkmarks.", Color.green),
        (
            "Chad",
            "💪",
            "We'll ALL be your coaches! When you lift, I'll be there spotting your form AND your content strategy.",
            Color.red
        ),
        (
            "Sierra",
            "🏃‍♀️",
            "When you run, I'll pace your cardio AND your posting schedule. Consistency is key!",
            Color.orange
        ),
        (
            "Zen",
            "🧘‍♂️",
            "And when you stretch, I'll guide your flexibility AND " +
                "your ability to bend the truth about your workout times.",
            Color.green
        ),
        (
            "Chad",
            "💪",
            "No matter what workout you do, the right coach will be there. The gains have waited long enough!",
            Color.red
        )
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("HOW IT WORKS")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

            // Scrollable conversation
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(Array(displayedMessages.enumerated()), id: \.offset) { index, message in
                            ConversationBubbleView(message: message)
                                .id(index)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 400)
                .onChange(of: displayedMessages.count) { _, newCount in
                    if newCount > 0 {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
            }

            Spacer()

            // Show button only when conversation is complete
            if conversationComplete {
                Button(action: {
                    // Complete onboarding
                    authManager.completeOnboarding()
                    
                    // Now that onboarding is complete, start health services
                    container.workoutObserver.startObservingWorkouts()
                    container.workoutAutoShareService.setupAutoSharing()
                }, label: {
                    Text("Let's Get Started!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.3))
                        .cornerRadius(15)
                })
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            startConversation()
        }
    }
    
    private func startConversation() {
        // Reset state
        displayedMessages = []
        conversationComplete = false
        
        // Start adding messages with delays
        for (index, dialogue) in dialogues.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2.0) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    displayedMessages.append(ConversationMessage(
                        name: dialogue.0,
                        emoji: dialogue.1,
                        message: dialogue.2,
                        color: dialogue.3
                    ))
                }
                
                // Mark conversation complete after last message
                if index == dialogues.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                            conversationComplete = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    let container = DependencyContainer()
    return OnboardingView()
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutObserver)
        .environment(\.dependencyContainer, container)
}
