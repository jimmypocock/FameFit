import SwiftUI

struct MainView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @EnvironmentObject var workoutObserver: WorkoutObserver
    
    #if DEBUG
    func resetAppForTesting() {
        // Clear all UserDefaults
        let keys = ["FameFitUserID", "FameFitUserName", "hasCompletedOnboarding", "selectedCharacter"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
        
        // Sign out
        authManager.signOut()
        
        // Reset CloudKit data
        cloudKitManager.followerCount = 0
        cloudKitManager.totalWorkouts = 0
        cloudKitManager.currentStreak = 0
    }
    #endif

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("Welcome back,")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(cloudKitManager.userName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Followers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(cloudKitManager.followerCount)")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(cloudKitManager.getFollowerTitle())
                                .font(.headline)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)

                    HStack {
                        StatCard(title: "Workouts", value: "\(cloudKitManager.totalWorkouts)", icon: "figure.run")
                        StatCard(title: "Streak", value: "\(cloudKitManager.currentStreak)", icon: "flame.fill")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Journey")
                        .font(.headline)

                    Text("Complete workouts in any app to gain followers! " +
                            "Your coaches will congratulate you after each workout.")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("Current rate: +5 followers per workout")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(15)

                Spacer()

                Button(action: {
                    authManager.signOut()
                }, label: {
                    Text("Sign Out")
                        .foregroundColor(.red)
                })
                
                #if DEBUG
                Button(action: {
                    resetAppForTesting()
                }, label: {
                    Text("Reset App (Debug)")
                        .foregroundColor(.orange)
                })
                #endif
            }
            .padding()
            .navigationTitle("FameFit")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Ensure workout observer is running
            workoutObserver.startObservingWorkouts()
            // Refresh user data
            cloudKitManager.fetchUserRecord()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

#Preview {
    let container = DependencyContainer()
    return MainView()
        .environmentObject(container.authenticationManager)
        .environmentObject(container.cloudKitManager)
        .environmentObject(container.workoutObserver)
        .environment(\.dependencyContainer, container)
}
