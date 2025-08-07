//
//  PrivacyQuickSettingsView.swift
//  FameFit
//
//  Quick privacy settings for bulk updating activity sharing defaults
//

import SwiftUI

struct PrivacyQuickSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container
    
    @State private var settings = ActivityFeedSettings(userID: "")
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasChanges = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Quick Settings")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Set default privacy levels for all your automatically shared activities.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Bulk update section
                        bulkUpdateSection
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Individual settings
                        individualSettingsSection
                        
                        // Info footer
                        infoFooter
                    }
                    .padding(.vertical)
                }
                
                // Save button
                saveButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
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
    }
    
    // MARK: - Sections
    
    private var bulkUpdateSection: some View {
        VStack(spacing: 16) {
            Text("Set all activities to:")
                .font(.headline)
            
            HStack(spacing: 12) {
                privacyButton(.private)
                privacyButton(.friendsOnly)
                privacyButton(.public)
            }
        }
        .padding(.horizontal)
    }
    
    private var individualSettingsSection: some View {
        VStack(spacing: 20) {
            Text("Or adjust individually:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                privacyRow("Workouts", icon: "figure.run", binding: $settings.workoutPrivacy)
                privacyRow("Achievements", icon: "trophy", binding: $settings.achievementPrivacy)
                privacyRow("Level Ups", icon: "arrow.up.circle", binding: $settings.levelUpPrivacy)
                privacyRow("Milestones", icon: "flag.checkered", binding: $settings.milestonePrivacy)
                privacyRow("Streaks", icon: "flame", binding: $settings.streakPrivacy)
            }
            .padding(.horizontal)
        }
    }
    
    private var infoFooter: some View {
        VStack(spacing: 8) {
            Label("These settings apply to all future activities shared automatically.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Text("Past activities retain their original privacy settings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var saveButton: some View {
        Button(action: saveSettings) {
            HStack {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Save Changes")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(hasChanges ? Color.blue : Color(.systemGray3))
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!hasChanges || isSaving)
        }
        .padding()
    }
    
    // MARK: - Helper Views
    
    private func privacyButton(_ privacy: WorkoutPrivacy) -> some View {
        Button(action: { setAllPrivacy(privacy) }) {
            VStack(spacing: 8) {
                Image(systemName: privacy.icon)
                    .font(.title2)
                Text(privacy.displayName)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray5))
            .cornerRadius(12)
        }
    }
    
    private func privacyRow(_ title: String, icon: String, binding: Binding<WorkoutPrivacy>) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.body)
            
            Spacer()
            
            Menu {
                ForEach(WorkoutPrivacy.allCases, id: \.self) { privacy in
                    Button(action: { 
                        binding.wrappedValue = privacy
                        hasChanges = true
                    }) {
                        Label(privacy.displayName, systemImage: privacy.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: binding.wrappedValue.icon)
                        .font(.caption)
                    Text(binding.wrappedValue.displayName)
                        .font(.body)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
        Task {
            do {
                isLoading = true
                settings = try await container.activitySharingSettingsService.loadSettings()
                isLoading = false
            } catch {
                errorMessage = "Failed to load settings: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }
    
    private func setAllPrivacy(_ privacy: WorkoutPrivacy) {
        settings.workoutPrivacy = privacy
        settings.achievementPrivacy = privacy
        settings.levelUpPrivacy = privacy
        settings.milestonePrivacy = privacy
        settings.streakPrivacy = privacy
        hasChanges = true
    }
    
    private func saveSettings() {
        Task {
            do {
                isSaving = true
                try await container.activitySharingSettingsService.saveSettings(settings)
                hasChanges = false
                isSaving = false
                
                // Dismiss after successful save
                dismiss()
            } catch {
                errorMessage = "Failed to save settings: \(error.localizedDescription)"
                showError = true
                isSaving = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacyQuickSettingsView()
        .environmentObject(DependencyContainer())
}