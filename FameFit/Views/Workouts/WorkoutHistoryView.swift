import HealthKit
import SwiftUI

struct WorkoutHistoryView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Environment(\.dependencyContainer) var dependencyContainer
    @State private var workoutHistory: [WorkoutHistoryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTransaction: XPTransaction?
    @State private var showingXPBreakdown = false

    var totalXP: Int {
        workoutHistory.reduce(0) { $0 + $1.effectiveXPEarned }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading workout history...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workoutHistory.isEmpty {
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
            loadWorkoutHistory()
        }
        .sheet(isPresented: $showingXPBreakdown) {
            if let transaction = selectedTransaction {
                XPTransactionDetailView(transaction: transaction)
            }
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
                        Text("From \(workoutHistory.count) workouts")
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
                ForEach(workoutHistory) { workout in
                    WorkoutHistoryRow(workout: workout)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            fetchXPTransaction(for: workout)
                        }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }

    private func loadWorkoutHistory() {
        cloudKitManager.fetchWorkoutHistory { result in
            DispatchQueue.main.async { [self] in
                switch result {
                case let .success(history):
                    workoutHistory = history
                    isLoading = false
                    if !history.isEmpty {
                        FameFitLogger.info(
                            "☁️ Loaded \(history.count) workouts from CloudKit",
                            category: FameFitLogger.app
                        )
                    }
                case let .failure(error):
                    errorMessage = "Unable to load workout history"
                    isLoading = false
                    FameFitLogger.error("Failed to load workout history", error: error, category: FameFitLogger.app)
                }
            }
        }
    }
    
    private func fetchXPTransaction(for workout: WorkoutHistoryItem) {
        Task {
            do {
                let transaction = try await dependencyContainer.xpTransactionService
                    .fetchTransaction(for: workout.id.uuidString)
                
                if let transaction = transaction {
                    await MainActor.run {
                        self.selectedTransaction = transaction
                        self.showingXPBreakdown = true
                    }
                } else {
                    // No transaction found - create one on the fly for display
                    let userStats = UserStats(
                        totalWorkouts: cloudKitManager.totalWorkouts,
                        currentStreak: cloudKitManager.currentStreak,
                        recentWorkouts: [],
                        totalXP: cloudKitManager.totalXP
                    )
                    
                    let result = XPCalculator.calculateXP(for: workout, userStats: userStats)
                    
                    await MainActor.run {
                        self.selectedTransaction = XPTransaction(
                            userRecordID: cloudKitManager.currentUserID ?? "",
                            workoutRecordID: workout.id.uuidString,
                            baseXP: result.baseXP,
                            finalXP: result.finalXP,
                            factors: result.factors
                        )
                        self.showingXPBreakdown = true
                    }
                }
            } catch {
                FameFitLogger.error(
                    "Failed to fetch XP transaction",
                    error: error,
                    category: FameFitLogger.app
                )
            }
        }
    }
}

struct WorkoutHistoryRow: View {
    let workout: WorkoutHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.workoutType)
                        .font(.headline)

                    Text(workout.startDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(workout.startDate, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(workout.effectiveXPEarned) XP")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Tap for details")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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
    WorkoutHistoryView()
        .environmentObject(DependencyContainer().cloudKitManager)
}
