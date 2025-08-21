import HealthKit
import SwiftUI
import Foundation

struct WorkoutHistoryView: View {
    @EnvironmentObject var cloudKitManager: CloudKitService
    @Environment(\.dependencyContainer) var dependencyContainer
    @State private var workoutHistory: [Workout] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTransaction: XPTransaction?
    @State private var showingXPBreakdown = false
    @State private var healthKitAuthStatus: HKAuthorizationStatus = .notDetermined
    @State private var isRequestingHealthKitAccess = false
    
    private let healthStore = HKHealthStore()

    // Use cached values as single source of truth
    var totalXP: Int {
        cloudKitManager.totalXP
    }
    
    var totalWorkouts: Int {
        cloudKitManager.totalWorkouts
    }

    var body: some View {
        VStack(spacing: 0) {
            // HealthKit permission banner - only shows when not determined
            if healthKitAuthStatus == .notDetermined {
                healthKitPermissionBanner
            }
            
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
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            checkHealthKitAuthorization()
            loadWorkoutHistory()
        }
        .sheet(isPresented: $showingXPBreakdown) {
            if let transaction = selectedTransaction {
                XPTransactionDetailView(transaction: transaction)
            }
        }
    }
    
    private var healthKitPermissionBanner: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("HealthKit Access Required")
                        .font(.headline)
                    Text("Grant access to sync your workouts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Button(action: {
                requestHealthKitAccess()
            }) {
                HStack {
                    if isRequestingHealthKitAccess {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "heart.text.square.fill")
                    }
                    Text("Grant Access")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isRequestingHealthKitAccess)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding()
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

    private func checkHealthKitAuthorization() {
        let workoutType = HKObjectType.workoutType()
        healthKitAuthStatus = healthStore.authorizationStatus(for: workoutType)
    }
    
    private func requestHealthKitAccess() {
        isRequestingHealthKitAccess = true
        
        // Use the existing HealthKit service to request authorization
        let healthKitService = dependencyContainer.healthKitService
        
        healthKitService.requestAuthorization { success, error in
            DispatchQueue.main.async {
                self.isRequestingHealthKitAccess = false
                
                if success {
                    // Check the new status
                    self.checkHealthKitAuthorization()
                    
                    // Trigger a sync if permission was granted
                    if self.healthKitAuthStatus != .notDetermined {
                        Task {
                            await self.dependencyContainer.workoutSyncManager.performManualSync()
                        }
                    }
                } else if let error = error {
                    self.errorMessage = "Failed to request HealthKit access: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadWorkoutHistory() {
        cloudKitManager.fetchWorkouts { result in
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
    
    private func fetchXPTransaction(for workout: Workout) {
        Task {
            do {
                let transaction = try await dependencyContainer.xpTransactionService
                    .fetchTransaction(for: workout.id)
                
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
                            userID: cloudKitManager.currentUserID ?? "",
                            workoutID: workout.id,
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
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.displayName)
                        .font(.headline)

                    Text(workout.startDate.workoutDisplayDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(workout.startDate.workoutDisplayTime)
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
