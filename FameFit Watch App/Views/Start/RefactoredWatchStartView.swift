//
//  RefactoredWatchStartView.swift
//  FameFit Watch App
//
//  Clean view with all business logic moved to ViewModel
//

import SwiftUI
import HealthKit

struct RefactoredWatchStartView: View {
    // MARK: - Dependencies
    
    @ObservedObject var viewModel: WatchStartViewModel
    @EnvironmentObject var sessionViewModel: SessionViewModel
    
    // MARK: - State
    
    @State private var showingWorkoutSelection = false
    @State private var navigateToSession = false
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Group Workouts Section
                if viewModel.hasGroupWorkouts {
                    groupWorkoutsSection
                }
                
                // Quick Start Section
                quickStartSection
            }
            .padding(.horizontal)
        }
        .navigationTitle("FameFit")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $navigateToSession) {
            SessionPagingView()
        }
        .alert("Error", isPresented: $viewModel.showingErrorAlert) {
            Button("OK") {
                viewModel.showingErrorAlert = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .refreshable {
            await viewModel.refreshGroupWorkouts()
        }
        .onAppear {
            Task {
                await viewModel.refreshGroupWorkouts()
            }
        }
    }
    
    // MARK: - Sections
    
    private var groupWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Group Workouts")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            // Active workouts
            ForEach(viewModel.activeGroupWorkouts) { workout in
                WatchGroupWorkoutCard(workout: workout) {
                    Task {
                        await startGroupWorkout(workout)
                    }
                }
            }
            
            // Upcoming workouts
            ForEach(viewModel.upcomingGroupWorkouts.prefix(3)) { workout in
                WatchGroupWorkoutCard(workout: workout) {
                    Task {
                        await startGroupWorkout(workout)
                    }
                }
            }
        }
    }
    
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Start")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            Button(action: {
                showingWorkoutSelection = true
            }) {
                HStack {
                    Image(systemName: "figure.mixed.cardio")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("Start Workout")
                            .font(.headline)
                        Text("Choose activity type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showingWorkoutSelection) {
                WorkoutSelectionView(
                    workoutTypes: viewModel.workoutTypes,
                    onSelect: { type in
                        viewModel.selectWorkout(type)
                        showingWorkoutSelection = false
                        Task {
                            await startRegularWorkout()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func startGroupWorkout(_ workout: WatchGroupWorkout) async {
        await viewModel.startGroupWorkout(workout)
        await sessionViewModel.startWorkout()
        navigateToSession = true
    }
    
    private func startRegularWorkout() async {
        await sessionViewModel.startWorkout()
        navigateToSession = true
    }
}

// MARK: - Group Workout Card

struct WatchGroupWorkoutCard: View {
    let workout: WatchGroupWorkout
    let action: () -> Void
    
    private var isJoinable: Bool {
        // A workout is joinable if it hasn't ended and has space
        workout.scheduledEnd > Date() && workout.currentParticipants < workout.maxParticipants
    }
    
    private var timeUntilStart: String {
        let interval = workout.scheduledStart.timeIntervalSince(Date())
        if interval <= 0 {
            return "Active Now"
        } else if interval < 300 {
            return "Starting Soon"
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: workout.scheduledStart, relativeTo: Date())
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(workout.currentParticipants)")
                            .font(.caption)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(timeUntilStart)
                            .font(.caption)
                            .foregroundColor(isJoinable ? .green : .secondary)
                    }
                }
                
                Spacer()
                
                // Show crown if user is host (would need to check against current user ID)
                // For now, hide this since we don't have current user context here
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(isJoinable ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isJoinable)
    }
}

// MARK: - Workout Selection View

struct WorkoutSelectionView: View {
    let workoutTypes: [HKWorkoutActivityType]
    let onSelect: (HKWorkoutActivityType) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(workoutTypes, id: \.self) { type in
                Button(action: {
                    onSelect(type)
                }) {
                    HStack {
                        Image(systemName: icon(for: type))
                            .font(.title2)
                            .foregroundColor(.green)
                            .frame(width: 30)
                        
                        Text(name(for: type))
                            .font(.headline)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .navigationTitle("Choose Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func icon(for type: HKWorkoutActivityType) -> String {
        // Use centralized workout type configuration
        return WorkoutTypes.icon(for: type)
    }
    
    private func name(for type: HKWorkoutActivityType) -> String {
        // Use centralized workout type configuration
        return WorkoutTypes.name(for: type)
    }
}