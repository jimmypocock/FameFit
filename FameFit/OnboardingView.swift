import SwiftUI
import HealthKit

struct OnboardingView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var workoutObserver: WorkoutObserver

    @State private var onboardingStep = 0
    @State private var showSignIn = false
    @State private var healthKitAuthorized = false
    @State private var selectedWorkoutType: FameFitCharacter?

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
                    GameMechanicsView(onboardingStep: $onboardingStep)
                case 4:
                    WorkoutSelectionView(selectedWorkoutType: $selectedWorkoutType)
                default:
                    Text("Welcome to FameFit!")
                }
            }
            .padding()
        }
    }
}

struct WelcomeView: View {
    @Binding var onboardingStep: Int
    @State private var currentDialogue = 0

    let dialogues = [
        ("Chad", "💪", "Yo! Welcome to FameFit! I'm Chad Maximus, and these are my... coworkers.", Color.red),
        ("Sierra", "🏃‍♀️", "Business partners, Chad. We're business partners. Anyway, I'm Sierra Pace, " +
            "and fun fact: I've already burned 47 calories just standing here!", Color.orange),
        ("Zen", "🧘‍♂️", "And I'm Zen Flexington, here to align your chakras and your follower count. " +
            "Deep breath in... and exhale those amateur fitness vibes.", Color.green),
        ("Chad", "💪", "Listen up! We're the top fitness influencers at FameFit, " +
            "and we're here to make YOU Insta-famous!", Color.red),
        ("Sierra", "🏃‍♀️", "Because let's be real - working out without posting about it " +
            "is just... sweating for free.", Color.orange),
        ("Zen", "🧘‍♂️", "The universe has brought you here to manifest your destiny. " +
            "And by universe, I mean the algorithm.", Color.green),
        ("Chad", "💪", "Let's get you started by making sure we can see your gains.", Color.red)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("FAMEFIT")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            if currentDialogue < dialogues.count {
                let dialogue = dialogues[currentDialogue]

                VStack(spacing: 15) {
                    Text(dialogue.1)
                        .font(.system(size: 60))

                    Text(dialogue.0)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(dialogue.2)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(dialogue.3.opacity(0.3))
                .cornerRadius(20)
            }

            Spacer()

            Button(action: {
                withAnimation {
                    if currentDialogue < dialogues.count - 1 {
                        currentDialogue += 1
                    } else {
                        onboardingStep = 1
                    }
                }
            }, label: {
                Text(currentDialogue < dialogues.count - 1 ? "Next" : "Let's Go!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(15)
            })
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
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
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

                Text("This lets us:\n• Detect when you complete workouts\n• Track your progress\n• Award you followers for your efforts")
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

struct GameMechanicsView: View {
    @Binding var onboardingStep: Int
    @State private var currentDialogue = 0

    let dialogues = [
        ("Chad", "💪", "Perfect. Now, here's the deal: Every workout you crush gets you followers.", Color.red),
        ("Sierra", "🏃‍♀️", "And more followers means SPONSORSHIPS! I'm talking free protein powder, " +
            "workout gear, and those weird teas nobody actually drinks!", Color.orange),
        ("Zen", "🧘‍♂️", "And don't forget the exclusive events. Last week I did yoga with " +
            "a B-list celebrity's personal assistant's dog walker. Networking!", Color.green),
        ("Chad", "💪", "Plus, once you hit certain follower milestones, you unlock the VIP stuff - " +
            "celebrity gym parties, influencer retreats...", Color.red),
        ("Sierra", "🏃‍♀️", "...5K runs with people who actually care about your split times...", Color.orange),
        ("Zen", "🧘‍♂️", "...and meditation sessions where we collectively manifest verified checkmarks.", Color.green),
        ("Chad", "💪", "We'll be your coaches! When you lift, I'll be there spotting your form AND your content strategy.", Color.red),
        ("Sierra", "🏃‍♀️", "When you run, I'll pace your cardio AND your posting schedule. Consistency is key!", Color.orange),
        ("Zen", "🧘‍♂️", "And when you stretch, I'll guide your flexibility AND " +
            "your ability to bend the truth about your workout times.", Color.green),
        ("Chad", "💪", "The gains have waited long enough. Let's get started!", Color.red)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("HOW IT WORKS")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            if currentDialogue < dialogues.count {
                let dialogue = dialogues[currentDialogue]

                VStack(spacing: 15) {
                    Text(dialogue.1)
                        .font(.system(size: 60))

                    Text(dialogue.0)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(dialogue.2)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(dialogue.3.opacity(0.3))
                .cornerRadius(20)
            }

            Spacer()

            Button(action: {
                withAnimation {
                    if currentDialogue < dialogues.count - 1 {
                        currentDialogue += 1
                    } else {
                        onboardingStep = 4
                    }
                }
            }, label: {
                Text(currentDialogue < dialogues.count - 1 ? "Next" : "Choose Your Coach!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(15)
            })
        }
    }
}

struct WorkoutSelectionView: View {
    @Binding var selectedWorkoutType: FameFitCharacter?
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 20) {
            Text("CHOOSE YOUR SPECIALTY")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text("Pick your main workout type\n(You can do any workout and we'll match you with the right coach!)")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Spacer()

            ForEach(FameFitCharacter.allCases, id: \.self) { character in
                Button(action: {
                    selectedWorkoutType = character
                }, label: {
                    HStack {
                        Text(character.emoji)
                            .font(.system(size: 40))

                        VStack(alignment: .leading) {
                            Text(character.specialty)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(character.fullName)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        Spacer()
                    }
                    .padding()
                    .background(characterColor(for: character).opacity(0.3))
                    .cornerRadius(15)
                })
            }

            Spacer()
        }
    }

    func characterColor(for character: FameFitCharacter) -> Color {
        switch character {
        case .chad: return .red
        case .sierra: return .orange
        case .zen: return .green
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
