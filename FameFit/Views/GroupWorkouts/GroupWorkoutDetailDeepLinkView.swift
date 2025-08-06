//
//  GroupWorkoutDetailDeepLinkView.swift
//  FameFit
//
//  Handles deep linking to group workout details by ID
//

import SwiftUI

struct GroupWorkoutDetailDeepLinkView: View {
    let workoutId: String
    @Environment(\.dependencyContainer) private var container
    @State private var workout: GroupWorkout?
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading workout...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let workout = workout {
                GroupWorkoutDetailView(workout: workout)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                    
                    Text("Workout Not Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let error = error {
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWorkout()
        }
    }
    
    private func loadWorkout() async {
        isLoading = true
        
        do {
            // Fetch the workout by ID
            let fetchedWorkout = try await container.groupWorkoutService.fetchWorkout(workoutId)
            workout = fetchedWorkout
        } catch {
            FameFitLogger.error("Failed to load workout for deep link", error: error, category: FameFitLogger.ui)
            self.error = error
        }
        
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        GroupWorkoutDetailDeepLinkView(workoutId: "test-workout-id")
            .environment(\.dependencyContainer, DependencyContainer())
    }
}