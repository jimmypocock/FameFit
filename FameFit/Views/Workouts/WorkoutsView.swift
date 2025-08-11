import HealthKit
import SwiftUI
import Foundation

struct WorkoutsView: View {
    @EnvironmentObject var cloudKitManager: CloudKitService
    @State private var workouts: [Workout] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Use cached values as single source of truth
    var totalXP: Int {
        cloudKitManager.totalXP
    }
    
    var totalWorkouts: Int {
        cloudKitManager.totalWorkouts
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading workouts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workouts.isEmpty {
                emptyStateView
            } else {
                workoutListView
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            loadWorkouts()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Workouts Yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Complete workouts to see them here\nWorkouts are tracked from any fitness app")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var workoutListView: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total XP Earned")
                            .font(.headline)
                        Text("From \(totalWorkouts) workouts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(totalXP) XP")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 8)
            }

            Section("Workouts") {
                ForEach(workouts) { workout in
                    WorkoutRow(workout: workout)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private func loadWorkouts() {
        cloudKitManager.fetchWorkouts { result in
            DispatchQueue.main.async {
                switch result {
                case let .success(history):
                    workouts = history
                    isLoading = false
                    if !history.isEmpty {
                        FameFitLogger.info(
                            "☁️ Loaded \(history.count) workouts from CloudKit",
                            category: FameFitLogger.app
                        )
                    }
                case let .failure(error):
                    errorMessage = "Unable to load workouts"
                    isLoading = false
                    FameFitLogger.error("Failed to load workouts", error: error, category: FameFitLogger.app)
                }
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.workoutType)
                        .font(.headline)

                    Text(workout.startDate.workoutDisplayDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(workout.startDate.workoutDisplayTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("+\(workout.effectiveXPEarned) XP")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            HStack(spacing: 20) {
                Label(workout.formattedDuration, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label(workout.formattedCalories, systemImage: "flame")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let distance = workout.formattedDistance {
                    Label(distance, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let heartRate = workout.averageHeartRate {
                    Label("\(Int(heartRate)) bpm", systemImage: "heart")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("Source: \(workout.source)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkoutsView()
        .environmentObject(DependencyContainer().cloudKitManager)
}
