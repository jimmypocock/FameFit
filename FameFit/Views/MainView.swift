import SwiftUI
import os.log

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var showingNotifications = false
    @State private var showingWorkoutHistory = false
    
    init(viewModel: MainViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("Welcome back,")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text(viewModel.userName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }

                VStack(spacing: 20) {
                    XPProgressView(currentXP: viewModel.influencerXP)

                    HStack {
                        Button(action: {
                            showingWorkoutHistory = true
                        }) {
                            StatCard(title: "Workouts", value: "\(viewModel.totalWorkouts)", icon: "figure.run")
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        StatCard(title: "Streak", value: "\(viewModel.currentStreak)", icon: "flame.fill")
                    }
                    
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Member Since")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let joinDate = viewModel.joinDate {
                                    Text(joinDate, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Today")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Last Workout")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let lastWorkout = viewModel.lastWorkoutDate {
                                    Text(lastWorkout, style: .relative)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                } else {
                                    Text("None yet")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(15)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("FameFit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingNotifications = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                            
                            if viewModel.hasUnreadNotifications {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            viewModel.signOut()
                        }) {
                            Label("Sign Out", systemImage: "arrow.right.square")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsListView()
        }
        .sheet(isPresented: $showingWorkoutHistory) {
            WorkoutHistoryView()
        }
        .onAppear {
            viewModel.refreshData()
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
    let viewModel = MainViewModel(
        authManager: container.authenticationManager,
        cloudKitManager: container.cloudKitManager,
        notificationStore: container.notificationStore
    )
    return MainView(viewModel: viewModel)
}
