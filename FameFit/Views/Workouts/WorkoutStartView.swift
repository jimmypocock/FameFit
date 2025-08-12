//
//  WorkoutStartView.swift
//  FameFit
//
//  View for starting workouts from iPhone
//

import SwiftUI
import HealthKit
import WatchConnectivity

struct WorkoutStartView: View {
    @Environment(\.dependencyContainer) var container
    @State private var isCheckingWatchConnection = false
    @State private var showWatchNotConnectedAlert = false
    @State private var selectedWorkoutType: HKWorkoutActivityType?
    
    // Use centralized primary workout types
    private var workoutTypes: [WorkoutTypeConfig] {
        WorkoutTypes.primary
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Watch connection status
                watchConnectionCard
                
                // Workout type cards
                VStack(spacing: 16) {
                    ForEach(workoutTypes, id: \.id) { config in
                        WorkoutTypeCard(
                            workoutType: config.type,
                            name: config.name,
                            icon: config.icon,
                            color: config.color,
                            onTap: {
                                startWorkout(type: config.type)
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .alert("Apple Watch Not Connected", isPresented: $showWatchNotConnectedAlert) {
            Button("OK") { }
        } message: {
            Text("Please make sure your Apple Watch is paired and the FameFit app is installed.")
        }
    }
    
    // MARK: - Watch Connection Card
    
    private var watchConnectionCard: some View {
        HStack {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundColor(isWatchConnected ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isWatchConnected ? "Apple Watch Connected" : "Apple Watch Not Connected")
                    .font(.headline)
                
                Text(isWatchConnected ? 
                     "Tap a workout below to start on your watch" : 
                     "Connect your Apple Watch to start workouts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isWatchConnected {
                Button("Check") {
                    checkWatchConnection()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var isWatchConnected: Bool {
        container.watchConnectivityManager.isReachable
    }
    
    // MARK: - Actions
    
    private func checkWatchConnection() {
        isCheckingWatchConnection = true
        
        Task {
            let isConnected = container.watchConnectivityManager.isReachable
            DispatchQueue.main.async {
                isCheckingWatchConnection = false
                if !isConnected {
                    showWatchNotConnectedAlert = true
                }
            }
        }
    }
    
    private func startWorkout(type: HKWorkoutActivityType) {
        guard isWatchConnected else {
            showWatchNotConnectedAlert = true
            return
        }
        
        // Send message to watch to start workout
        Task {
                try await container.watchConnectivityManager.startWorkout(type: Int(type.rawValue))
        }
    }
}

// MARK: - Workout Type Card

struct WorkoutTypeCard: View {
    let workoutType: HKWorkoutActivityType
    let name: String
    let icon: String
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                // Title and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Tap to start on Apple Watch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WorkoutStartView()
        .environment(\.dependencyContainer, DependencyContainer())
}
