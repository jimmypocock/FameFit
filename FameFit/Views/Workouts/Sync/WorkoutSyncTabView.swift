//
//  WorkoutSyncTabView.swift
//  FameFit
//
//  Debug view for manually syncing HealthKit workouts to CloudKit
//

import SwiftUI
import HealthKit

struct WorkoutSyncTabView: View {
    @Environment(\.dependencyContainer) private var container
    @StateObject private var viewModel: WorkoutSyncViewModel
    
    init() {
        // ViewModels are initialized with proper services from DependencyContainer
        // This prevents initialization issues
        let container = DependencyContainer()
        _viewModel = StateObject(wrappedValue: WorkoutSyncViewModel(
            cloudKitService: container.cloudKitManager,
            workoutProcessor: container.workoutProcessor,
            userProfileService: container.userProfileService
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // CloudKit Status Section
                cloudKitStatusSection
                
                Divider()
                
                // Header with scan button
                VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await viewModel.scanHealthKit()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Scan for Workouts")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isLoading)
                
                // Status messages
                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                if !viewModel.successMessage.isEmpty {
                    Text(viewModel.successMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            
                // Workout list
                if viewModel.workouts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No workouts found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Tap 'Scan Last 24 Hours' to search for workouts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.workouts) { item in
                            WorkoutSyncRow(item: item)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sync button at bottom
                    let unsyncedCount = viewModel.workouts.filter { !$0.isSynced }.count
                    if unsyncedCount > 0 {
                        Button(action: {
                            Task {
                                await viewModel.syncWorkoutsToCloudKit()
                            }
                        }) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                Text("Sync \(unsyncedCount) Workout\(unsyncedCount == 1 ? "" : "s") to CloudKit")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .disabled(viewModel.isLoading)
                    }
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                }
            }
        }
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                // Check CloudKit status first
                await viewModel.checkCloudKitStatus()
                // Then scan for workouts
                await viewModel.scanHealthKit()
            }
        }
    }
    
    // MARK: - CloudKit Status Section
    
    private var cloudKitStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CloudKit Status")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                // iCloud Account Status
                HStack {
                    Text("iCloud Account:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.iCloudAccountStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                // CloudKit Connection
                HStack {
                    Text("CloudKit:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.cloudKitStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                // User ID
                HStack {
                    Text("User ID:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let userID = viewModel.cloudKitUserID {
                        Text(userID)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("Not available")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // User Profile Status
                HStack {
                    Text("Has Profile:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.hasUserProfile ? "✅ Yes" : "❌ No")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
            
            // Fetch User ID button if needed
            if viewModel.cloudKitUserID == nil {
                Button(action: {
                    Task {
                        await viewModel.fetchCloudKitUserID()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Fetch CloudKit User ID")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
            }
        }
    }
}

// MARK: - Workout Row View

struct WorkoutSyncRow: View {
    let item: WorkoutSyncViewModel.WorkoutSyncItem
    
    var workoutIcon: String {
        switch item.workout.workoutActivityType {
        case .running:
            return "🏃"
        case .walking:
            return "🚶"
        case .cycling:
            return "🚴"
        case .swimming:
            return "🏊"
        case .yoga:
            return "🧘"
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return "💪"
        default:
            return "🏋️"
        }
    }
    
    var body: some View {
        HStack {
            // Workout icon
            Text(workoutIcon)
                .font(.title2)
            
            // Workout details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.displayName)
                        .font(.headline)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item.duration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(item.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Sync status
            if item.isSynced {
                Label("Synced", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Label("Ready", systemImage: "arrow.up.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Preview

struct WorkoutSyncTabView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WorkoutSyncTabView()
                .environment(\.dependencyContainer, DependencyContainer())
        }
    }
}