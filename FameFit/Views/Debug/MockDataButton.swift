//
//  MockDataButton.swift
//  FameFit
//
//  Simple debug button for injecting mock workouts
//

#if DEBUG

import SwiftUI

struct MockDataButton: View {
    @State private var showingMenu = false
    
    private var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--mock-healthkit") ||
        ProcessInfo.processInfo.environment["USE_MOCK_HEALTHKIT"] == "1"
    }
    
    var body: some View {
        if isEnabled {
            Button(action: { showingMenu = true }) {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.orange)
            }
            .sheet(isPresented: $showingMenu) {
                MockDataMenu()
            }
        }
    }
}

struct MockDataMenu: View {
    @Environment(\.dismiss) private var dismiss
    @State private var injecting = false
    @State private var selectedMode = 0 // 0 = CloudKit, 1 = HealthKit
    
    var body: some View {
        NavigationView {
            List {
                Section("Injection Mode") {
                    Picker("Data Destination", selection: $selectedMode) {
                        Text("CloudKit (Shared)").tag(0)
                        Text("HealthKit (Local)").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text(selectedMode == 0 
                         ? "Injects directly to CloudKit - visible on both iPhone and Watch"
                         : "Injects to local HealthKit - only visible on this device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Quick Actions") {
                    Button(action: injectQuickWorkout) {
                        Label("Add 30min Run (Just Finished)", systemImage: "figure.run")
                    }
                    .disabled(injecting)
                    
                    Button(action: injectMorningRun) {
                        Label("Add Morning Run", systemImage: "sunrise")
                    }
                    .disabled(injecting)
                    
                    Button(action: injectHIIT) {
                        Label("Add Evening HIIT", systemImage: "flame")
                    }
                    .disabled(injecting)
                    
                    Button(action: injectWeekStreak) {
                        Label("Add 7-Day Streak", systemImage: "calendar")
                    }
                    .disabled(injecting)
                }
                
                Section("Simulate Watch Workout") {
                    Button(action: simulateWatchWorkout) {
                        Label("Simulate Watch → CloudKit Sync", systemImage: "applewatch")
                    }
                    .disabled(injecting || selectedMode == 1)
                    
                    if selectedMode == 1 {
                        Text("Watch simulation only works with CloudKit mode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Mock Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if injecting {
                    ProgressView("Injecting...")
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    private func injectQuickWorkout() {
        injecting = true
        
        if selectedMode == 0 {
            // CloudKit injection (shared between devices)
            MockCloudKitWorkoutInjector.shared.injectWorkout(scenario: .quickTest(duration: 30 * 60)) { success in
                injecting = false
                if success {
                    dismiss()
                }
            }
        } else {
            // HealthKit injection (local only)
            MockWorkoutInjector.shared.injectWorkout(scenario: .quickTest(duration: 30 * 60)) { success in
                injecting = false
                if success {
                    dismiss()
                }
            }
        }
    }
    
    private func injectMorningRun() {
        injecting = true
        
        if selectedMode == 0 {
            MockCloudKitWorkoutInjector.shared.injectWorkout(scenario: .morningRun) { success in
                injecting = false
                if success {
                    dismiss()
                }
            }
        } else {
            MockWorkoutInjector.shared.injectWorkout(scenario: .morningRun) { success in
                injecting = false
                if success {
                    dismiss()
                }
            }
        }
    }
    
    private func injectHIIT() {
        injecting = true
        
        if selectedMode == 0 {
            MockCloudKitWorkoutInjector.shared.injectWorkout(scenario: .eveningHIIT) { success in
                injecting = false
                if success {
                    dismiss()
                }
            }
        } else {
            MockWorkoutInjector.shared.injectWorkout(scenario: .eveningHIIT) { success in
                injecting = false
                if success {
                    dismiss()
                }
            }
        }
    }
    
    private func injectWeekStreak() {
        injecting = true
        
        if selectedMode == 0 {
            MockCloudKitWorkoutInjector.shared.injectWorkout(scenario: .weekStreak) { success in
                injecting = false
                if success {
                    dismiss()
                }
            }
        } else {
            MockWorkoutInjector.shared.injectWorkout(scenario: .weekStreak) { success in
                injecting = false
                if success {
                    dismiss()
                }
            }
        }
    }
    
    private func simulateWatchWorkout() {
        injecting = true
        
        MockCloudKitWorkoutInjector.shared.simulateWatchWorkout(
            type: "Running",
            duration: 25 * 60,
            energy: 275,
            distance: 4500
        ) { success in
            injecting = false
            if success {
                dismiss()
            }
        }
    }
}

#endif