//
//  ActivityFeedSettingsView.swift
//  FameFit
//
//  Settings interface for configuring automatic activity sharing
//

import SwiftUI
import HealthKit

struct ActivityFeedSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container
    
    @State private var settings = ActivityFeedSettings(userID: "")
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasUnsavedChanges = false
    @State private var showBulkPrivacyUpdate = false
    
    // Preset selection
    @State private var selectedPreset: SharingPreset = .custom
    
    enum SharingPreset: String, CaseIterable {
        case conservative = "Conservative"
        case balanced = "Balanced"
        case social = "Social"
        case custom = "Custom"
        
        var description: String {
            switch self {
            case .conservative:
                return "Share less, keep it private"
            case .balanced:
                return "Reasonable defaults for most users"
            case .social:
                return "Share more, be social"
            case .custom:
                return "Configure your own preferences"
            }
        }
        
        var icon: String {
            switch self {
            case .conservative:
                return "lock.shield"
            case .balanced:
                return "checkmark.shield"
            case .social:
                return "person.3"
            case .custom:
                return "slider.horizontal.3"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Master toggle
                masterToggleSection
                
                if settings.shareActivitiesToFeed {
                    // Preset selection
                    presetSection
                    
                    // Activity types
                    activityTypesSection
                    
                    // Workout settings
                    workoutSettingsSection
                    
                    // Privacy defaults
                    privacyDefaultsSection
                    
                    // Advanced settings
                    advancedSettingsSection
                }
            }
            .navigationTitle("Activity Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            // TODO: Show confirmation dialog
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(!hasUnsavedChanges || isSaving)
                }
            }
        }
        .onAppear {
            loadSettings()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showBulkPrivacyUpdate) {
            BulkPrivacyUpdateView(dependencyContainer: container)
        }
    }
    
    // MARK: - Sections
    
    private var masterToggleSection: some View {
        Section {
            Toggle("Share Activities Automatically", isOn: $settings.shareActivitiesToFeed)
                .onChange(of: settings.shareActivitiesToFeed) { _, _ in
                    hasUnsavedChanges = true
                }
        }
    }
    
    private var presetSection: some View {
        Section(header: Text("Quick Setup")) {
            ForEach(SharingPreset.allCases, id: \.self) { preset in
                Button(action: { applyPreset(preset) }) {
                    HStack {
                        Image(systemName: preset.icon)
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(preset.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedPreset == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var activityTypesSection: some View {
        Section(header: Text("Activity Types")) {
            Toggle("Workouts", isOn: $settings.shareWorkouts)
                .onChange(of: settings.shareWorkouts) { _, _ in
                    hasUnsavedChanges = true
                    selectedPreset = .custom
                }
            
            Toggle("Achievements", isOn: $settings.shareAchievements)
                .onChange(of: settings.shareAchievements) { _, _ in
                    hasUnsavedChanges = true
                    selectedPreset = .custom
                }
            
            Toggle("Level Ups", isOn: $settings.shareLevelUps)
                .onChange(of: settings.shareLevelUps) { _, _ in
                    hasUnsavedChanges = true
                    selectedPreset = .custom
                }
            
            Toggle("Milestones", isOn: $settings.shareMilestones)
                .onChange(of: settings.shareMilestones) { _, _ in
                    hasUnsavedChanges = true
                    selectedPreset = .custom
                }
            
            Toggle("Streaks", isOn: $settings.shareStreaks)
                .onChange(of: settings.shareStreaks) { _, _ in
                    hasUnsavedChanges = true
                    selectedPreset = .custom
                }
        }
    }
    
    private var workoutSettingsSection: some View {
        Section(header: Text("Workout Settings")) {
            // Minimum duration
            VStack(alignment: .leading) {
                Text("Minimum Duration")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                HStack {
                    Slider(
                        value: Binding(
                            get: { settings.minimumWorkoutDuration / 60 },
                            set: { settings.minimumWorkoutDuration = $0 * 60 }
                        ),
                        in: 0...60,
                        step: 1
                    )
                    
                    Text("\(Int(settings.minimumWorkoutDuration / 60)) min")
                        .font(.body.monospacedDigit())
                        .foregroundColor(.blue)
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .onChange(of: settings.minimumWorkoutDuration) { _, _ in
                hasUnsavedChanges = true
                selectedPreset = .custom
            }
            
            // Include details toggle
            Toggle("Include Workout Details", isOn: $settings.shareWorkoutDetails)
                .onChange(of: settings.shareWorkoutDetails) { _, _ in
                    hasUnsavedChanges = true
                    selectedPreset = .custom
                }
            
            // Workout types
            NavigationLink(destination: WorkoutTypesSelectionView(selectedTypes: $settings.workoutTypesToShare)) {
                HStack {
                    Text("Workout Types")
                    Spacer()
                    Text("\(settings.workoutTypesToShare.count) selected")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var privacyDefaultsSection: some View {
        Section(header: Text("Privacy Defaults")) {
            // Quick settings button
            NavigationLink(destination: PrivacyQuickSettingsView()) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.blue)
                    Text("Quick Privacy Settings")
                    Spacer()
                    Text("Bulk update")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            privacyPicker("Workouts", selection: $settings.workoutPrivacy)
            privacyPicker("Achievements", selection: $settings.achievementPrivacy)
            privacyPicker("Level Ups", selection: $settings.levelUpPrivacy)
            privacyPicker("Milestones", selection: $settings.milestonePrivacy)
            privacyPicker("Streaks", selection: $settings.streakPrivacy)
        }
    }
    
    private var advancedSettingsSection: some View {
        Section(header: Text("Advanced")) {
            // Sharing delay
            VStack(alignment: .leading) {
                Text("Sharing Delay")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                HStack {
                    Slider(
                        value: Binding(
                            get: { settings.sharingDelay / 60 },
                            set: { settings.sharingDelay = $0 * 60 }
                        ),
                        in: 0...30,
                        step: 1
                    )
                    
                    Text("\(Int(settings.sharingDelay / 60)) min")
                        .font(.body.monospacedDigit())
                        .foregroundColor(.blue)
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .onChange(of: settings.sharingDelay) { _, _ in
                hasUnsavedChanges = true
                selectedPreset = .custom
            }
            
            // Historical workouts
            Toggle("Share Past Workouts", isOn: $settings.shareHistoricalWorkouts)
                .onChange(of: settings.shareHistoricalWorkouts) { _, _ in
                    hasUnsavedChanges = true
                    selectedPreset = .custom
                }
            
            if settings.shareHistoricalWorkouts {
                Stepper("Last \(settings.historicalWorkoutMaxAge) days", 
                       value: $settings.historicalWorkoutMaxAge, 
                       in: 1...30)
                    .onChange(of: settings.historicalWorkoutMaxAge) { _, _ in
                        hasUnsavedChanges = true
                        selectedPreset = .custom
                    }
            }
            
            // Bulk privacy update
            Button {
                showBulkPrivacyUpdate = true
            } label: {
                HStack {
                    Label("Update Privacy for Existing Activities", systemImage: "lock.shield")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func privacyPicker(_ title: String, selection: Binding<WorkoutPrivacy>) -> some View {
        Picker(title, selection: selection) {
            ForEach(WorkoutPrivacy.allCases, id: \.self) { privacy in
                Label(privacy.displayName, systemImage: privacy.icon)
                    .tag(privacy)
            }
        }
        .onChange(of: selection.wrappedValue) { _, _ in
            hasUnsavedChanges = true
            selectedPreset = .custom
        }
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        Task {
            do {
                isLoading = true
                settings = try await container.activitySharingSettingsService.loadSettings()
                detectPreset()
                isLoading = false
            } catch {
                errorMessage = "Failed to load settings: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }
    
    private func saveSettings() {
        Task {
            do {
                isSaving = true
                try await container.activitySharingSettingsService.saveSettings(settings)
                hasUnsavedChanges = false
                isSaving = false
                dismiss()
            } catch {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
                showError = true
                isSaving = false
            }
        }
    }
    
    private func applyPreset(_ preset: SharingPreset) {
        selectedPreset = preset
        let userID = container.cloudKitManager.currentUserID ?? ""
        
        switch preset {
        case .conservative:
            settings = .conservative(userID: userID)
        case .balanced:
            settings = .balanced(userID: userID)
        case .social:
            settings = .social(userID: userID)
        case .custom:
            // Keep current settings
            break
        }
        
        hasUnsavedChanges = true
    }
    
    private func detectPreset() {
        let userID = container.cloudKitManager.currentUserID ?? ""
        // Check if current settings match any preset
        if settings == .conservative(userID: userID) {
            selectedPreset = .conservative
        } else if settings == .balanced(userID: userID) {
            selectedPreset = .balanced
        } else if settings == .social(userID: userID) {
            selectedPreset = .social
        } else {
            selectedPreset = .custom
        }
    }
}

// MARK: - Workout Types Selection View

struct WorkoutTypesSelectionView: View {
    @Binding var selectedTypes: Set<HKWorkoutActivityType>
    @Environment(\.dismiss) var dismiss
    
    private var allTypes: [HKWorkoutActivityType] {
        [
            .running, .walking, .cycling, .swimming,
            .functionalStrengthTraining, .traditionalStrengthTraining,
            .yoga, .hiking, .elliptical, .rowing,
            .stairClimbing, .highIntensityIntervalTraining,
            .crossTraining, .cardioDance, .boxing
        ]
    }
    
    var body: some View {
        List {
            Section {
                Button(action: selectAll) {
                    Text("Select All")
                        .foregroundColor(.blue)
                }
                
                Button(action: deselectAll) {
                    Text("Deselect All")
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Workout Types")) {
                ForEach(allTypes, id: \.self) { type in
                    HStack {
                        Image(systemName: workoutIcon(for: type))
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        Text(type.displayName)
                        
                        Spacer()
                        
                        if selectedTypes.contains(type) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedTypes.contains(type) {
                            selectedTypes.remove(type)
                        } else {
                            selectedTypes.insert(type)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Workout Types")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func selectAll() {
        selectedTypes = Set(allTypes)
    }
    
    private func deselectAll() {
        selectedTypes = []
    }
    
    private func workoutIcon(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running:
            return "figure.run"
        case .walking:
            return "figure.walk"
        case .cycling:
            return "bicycle"
        case .swimming:
            return "figure.pool.swim"
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return "dumbbell"
        case .yoga:
            return "figure.yoga"
        case .hiking:
            return "figure.hiking"
        case .cardioDance:
            return "figure.dance"
        case .boxing:
            return "figure.boxing"
        default:
            return "figure.mixed.cardio"
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityFeedSettingsView()
        .environmentObject(DependencyContainer())
}
