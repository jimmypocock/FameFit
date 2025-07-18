import SwiftUI
import HealthKit

struct WorkoutHistoryView: View {
    @EnvironmentObject var cloudKitManager: CloudKitManager
    @Environment(\.dismiss) var dismiss
    @State private var workoutHistory: [WorkoutHistoryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var totalFollowers: Int {
        workoutHistory.reduce(0) { $0 + $1.followersEarned }
    }
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
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
        }
        .onAppear {
            loadWorkoutHistory()
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
                        Text("Total Followers Earned")
                            .font(.headline)
                        Text("From \(workoutHistory.count) workouts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("+\(totalFollowers)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 8)
            }
            
            Section("Workouts") {
                ForEach(workoutHistory) { workout in
                    WorkoutHistoryRow(workout: workout)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func loadWorkoutHistory() {
        cloudKitManager.fetchWorkoutHistory { result in
            DispatchQueue.main.async { [self] in
                switch result {
                case .success(let history):
                    self.workoutHistory = history
                    self.isLoading = false
                    if !history.isEmpty {
                        FameFitLogger.info("☁️ Loaded \(history.count) workouts from CloudKit", category: FameFitLogger.app)
                    }
                case .failure(let error):
                    self.errorMessage = "Unable to load workout history"
                    self.isLoading = false
                    FameFitLogger.error("Failed to load workout history", error: error, category: FameFitLogger.app)
                }
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
                
                Text("+\(workout.followersEarned)")
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
    WorkoutHistoryView()
        .environmentObject(DependencyContainer().cloudKitManager)
}