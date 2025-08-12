//
//  DebugMenuView.swift
//  FameFit
//
//  Debug menu for development testing with mock data
//

#if DEBUG

import SwiftUI
import HealthKit

struct DebugMenuView: View {
    
    // MARK: - Properties
    
    @State private var isMockEnabled = ServiceResolver.isUsingMockData
    @State private var showingWorkoutPicker = false
    @State private var showingScheduler = false
    @State private var showingDataManager = false
    @State private var selectedScenario: MockHealthKitService.WorkoutScenario = .quickTest()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // Mock Service Toggle
                Section {
                    Toggle("Use Mock HealthKit", isOn: $isMockEnabled)
                        .onChange(of: isMockEnabled) { newValue in
                            toggleMockService(enabled: newValue)
                        }
                    
                    if isMockEnabled {
                        Label("Mock Mode Active", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Mock Service")
                } footer: {
                    Text("Enable to use mock HealthKit data instead of real data")
                }
                
                // Quick Actions
                if isMockEnabled {
                    Section("Quick Actions") {
                        Button(action: addJustCompletedWorkout) {
                            Label("Add Just Completed Workout", systemImage: "figure.run")
                        }
                        
                        Button(action: addTodaysWorkouts) {
                            Label("Add Today's Workouts", systemImage: "calendar")
                        }
                        
                        Button(action: addWeekStreak) {
                            Label("Add 7-Day Streak", systemImage: "flame")
                        }
                        
                        Button(action: addGroupWorkout) {
                            Label("Add Group Workout", systemImage: "person.3")
                        }
                        
                        Button(action: simulateBackgroundSync) {
                            Label("Simulate Background Sync", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    
                    // Workout Generation
                    Section("Workout Generation") {
                        NavigationLink(destination: WorkoutScenarioPicker()) {
                            Label("Generate Custom Workout", systemImage: "plus.circle")
                        }
                        
                        NavigationLink(destination: BulkGeneratorView()) {
                            Label("Bulk Generate Workouts", systemImage: "square.stack.3d.up")
                        }
                        
                        NavigationLink(destination: SchedulerView()) {
                            Label("Schedule Workouts", systemImage: "clock")
                        }
                    }
                    
                    // Data Management
                    Section("Data Management") {
                        NavigationLink(destination: MockDataManagerView()) {
                            Label("View Mock Data", systemImage: "tray.2")
                        }
                        
                        Button(action: clearAllData) {
                            Label("Clear All Mock Data", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        
                        Button(action: resetToDefaults) {
                            Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        }
                    }
                }
                
                // Debug Information
                Section("Debug Information") {
                    NavigationLink(destination: DebugInfoView()) {
                        Label("Service Configuration", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Debug Action", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleMockService(enabled: Bool) {
        if enabled {
            ServiceResolver.enableMockServices()
            loadMockData()
        } else {
            ServiceResolver.disableMockServices()
        }
        
        showAlert("Mock service \(enabled ? "enabled" : "disabled")")
    }
    
    private func addJustCompletedWorkout() {
        MockHealthKitService.shared.addJustCompletedWorkout()
        showAlert("Added workout that just completed")
    }
    
    private func addTodaysWorkouts() {
        MockHealthKitService.shared.addTodaysWorkouts()
        showAlert("Added today's workouts")
    }
    
    private func addWeekStreak() {
        MockHealthKitService.shared.addWeekStreak()
        showAlert("Added 7-day workout streak")
    }
    
    private func addGroupWorkout() {
        MockHealthKitService.shared.addRecentGroupWorkout()
        showAlert("Added group workout with 3 participants")
    }
    
    private func simulateBackgroundSync() {
        MockWorkoutScheduler.shared.simulateWatchSync(workoutCount: 3)
        showAlert("Simulating background sync (3 workouts)")
    }
    
    private func clearAllData() {
        MockHealthKitService.shared.clearAllWorkouts()
        MockDataStorage.shared.clearAll()
        showAlert("Cleared all mock data")
    }
    
    private func resetToDefaults() {
        ServiceResolver.resetMockData()
        loadDefaultMockData()
        showAlert("Reset to default mock data")
    }
    
    private func loadMockData() {
        let workouts = MockDataStorage.shared.loadWorkouts()
        MockHealthKitService.shared.injectWorkouts(workouts)
    }
    
    private func loadDefaultMockData() {
        // Generate some default data
        let weekWorkouts = MockHealthKitService.shared.generateWeekOfWorkouts()
        MockHealthKitService.shared.injectWorkouts(weekWorkouts)
        MockDataStorage.shared.saveWorkouts(weekWorkouts)
    }
    
    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Workout Scenario Picker

struct WorkoutScenarioPicker: View {
    @State private var selectedType: HKWorkoutActivityType = .running
    @State private var duration: Double = 30
    @State private var intensity: Double = 0.7
    @State private var startTimeOffset: Double = 0
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Workout Configuration") {
                Picker("Activity Type", selection: $selectedType) {
                    Text("Running").tag(HKWorkoutActivityType.running)
                    Text("Walking").tag(HKWorkoutActivityType.walking)
                    Text("Cycling").tag(HKWorkoutActivityType.cycling)
                    Text("HIIT").tag(HKWorkoutActivityType.highIntensityIntervalTraining)
                    Text("Strength").tag(HKWorkoutActivityType.functionalStrengthTraining)
                    Text("Yoga").tag(HKWorkoutActivityType.yoga)
                }
                
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(duration)) minutes")
                    Slider(value: $duration, in: 5...120, step: 5)
                }
                
                VStack(alignment: .leading) {
                    Text("Intensity: \(Int(intensity * 100))%")
                    Slider(value: $intensity, in: 0.3...1.0, step: 0.1)
                }
                
                VStack(alignment: .leading) {
                    Text("Start Time: \(Int(startTimeOffset)) hours ago")
                    Slider(value: $startTimeOffset, in: 0...24, step: 1)
                }
            }
            
            Section {
                Button("Generate Workout") {
                    generateWorkout()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Generate Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func generateWorkout() {
        let startDate = Date().addingTimeInterval(-startTimeOffset * 3600)
        let scenario = MockHealthKitService.WorkoutScenario.custom(
            type: selectedType,
            duration: duration * 60,
            intensity: intensity
        )
        
        let workout = MockHealthKitService.shared.generateWorkout(
            scenario: scenario,
            startDate: startDate
        )
        
        MockHealthKitService.shared.injectWorkout(workout)
        MockDataStorage.shared.appendWorkout(workout)
    }
}

// MARK: - Bulk Generator View

struct BulkGeneratorView: View {
    @State private var numberOfDays = 7
    @State private var workoutsPerDay = 1
    @State private var includeVariety = true
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section("Bulk Generation Settings") {
                Stepper("Days: \(numberOfDays)", value: $numberOfDays, in: 1...30)
                Stepper("Workouts per day: \(workoutsPerDay)", value: $workoutsPerDay, in: 1...5)
                Toggle("Include variety", isOn: $includeVariety)
            }
            
            Section {
                Button("Generate \(numberOfDays * workoutsPerDay) Workouts") {
                    generateBulkWorkouts()
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Bulk Generate")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func generateBulkWorkouts() {
        var allWorkouts: [HKWorkout] = []
        
        for day in 0..<numberOfDays {
            let date = Date().addingTimeInterval(-Double(day) * 86400)
            
            for _ in 0..<workoutsPerDay {
                let scenario: MockHealthKitService.WorkoutScenario
                
                if includeVariety {
                    scenario = [.morningRun, .eveningHIIT, .strengthTraining, .yoga, .recovery].randomElement() ?? .morningRun
                } else {
                    scenario = .morningRun
                }
                
                let workout = MockHealthKitService.shared.generateWorkout(
                    scenario: scenario,
                    startDate: date
                )
                allWorkouts.append(workout)
            }
        }
        
        MockHealthKitService.shared.injectWorkouts(allWorkouts)
        MockDataStorage.shared.saveWorkouts(allWorkouts)
    }
}

// MARK: - Scheduler View

struct SchedulerView: View {
    @State private var scheduledWorkouts: [ScheduledWorkout] = []
    @State private var isSchedulerActive = false
    
    var body: some View {
        List {
            Section {
                Toggle("Automatic Generation", isOn: $isSchedulerActive)
                    .onChange(of: isSchedulerActive) { newValue in
                        if newValue {
                            MockWorkoutScheduler.shared.startAutomaticGeneration()
                        } else {
                            MockWorkoutScheduler.shared.stopAutomaticGeneration()
                        }
                    }
            }
            
            Section("Quick Schedule") {
                Button("Simulate Realistic Day") {
                    MockWorkoutScheduler.shared.simulateRealisticDay()
                }
                
                Button("Simulate Watch Sync") {
                    MockWorkoutScheduler.shared.simulateWatchSync()
                }
                
                Button("Simulate Challenge Activity") {
                    MockWorkoutScheduler.shared.simulateChallengeActivity()
                }
            }
            
            Section("Scheduled Workouts") {
                if scheduledWorkouts.isEmpty {
                    Text("No scheduled workouts")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(scheduledWorkouts, id: \.id) { schedule in
                        VStack(alignment: .leading) {
                            Text(schedule.scenarioName)
                            Text(schedule.scheduledDate, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Scheduler")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            scheduledWorkouts = MockDataStorage.shared.loadScheduledWorkouts()
        }
    }
}

// MARK: - Mock Data Manager View

struct MockDataManagerView: View {
    @State private var workouts: [HKWorkout] = []
    
    var body: some View {
        List {
            Section("Stored Workouts (\(workouts.count))") {
                ForEach(workouts, id: \.uuid) { workout in
                    VStack(alignment: .leading) {
                        Text(workout.workoutActivityType.name)
                            .font(.headline)
                        HStack {
                            Text("\(Int(workout.duration / 60)) min")
                            Spacer()
                            Text(workout.endDate, style: .relative)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Mock Data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            workouts = MockDataStorage.shared.loadWorkouts()
        }
    }
}

// MARK: - Debug Info View

struct DebugInfoView: View {
    var body: some View {
        Form {
            Section("Service Configuration") {
                ForEach(Array(ServiceResolver.debugConfiguration.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key)
                        Spacer()
                        Text(String(describing: ServiceResolver.debugConfiguration[key] ?? ""))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Debug Info")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#endif