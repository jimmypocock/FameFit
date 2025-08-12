//
//  ActivitySharingMigrationView.swift
//  FameFit
//
//  One-time prompt for existing users to configure activity sharing
//

import SwiftUI

struct ActivitySharingMigrationView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container
    
    let onComplete: () -> Void
    
    @State private var selectedPreset: SharingPreset = .balanced
    @State private var showCustomSettings = false
    
    enum SharingPreset: String, CaseIterable {
        case minimal = "Minimal"
        case balanced = "Balanced" 
        case social = "Social"
        case off = "Off"
        
        var icon: String {
            switch self {
            case .minimal:
                return "lock.shield"
            case .balanced:
                return "checkmark.shield"
            case .social:
                return "person.3.fill"
            case .off:
                return "xmark.shield"
            }
        }
        
        var description: String {
            switch self {
            case .minimal:
                return "Share only long workouts privately"
            case .balanced:
                return "Share workouts with friends"
            case .social:
                return "Share everything publicly"
            case .off:
                return "Don't share automatically"
            }
        }
        
        var color: Color {
            switch self {
            case .minimal:
                return .orange
            case .balanced:
                return .blue
            case .social:
                return .green
            case .off:
                return .gray
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up.badge.clock")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("New: Automatic Activity Sharing")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your workouts can now automatically appear in your followers' feeds. Choose how you'd like to share:")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Preset Options
                VStack(spacing: 12) {
                    ForEach(SharingPreset.allCases, id: \.self) { preset in
                        PresetButton(
                            preset: preset,
                            isSelected: selectedPreset == preset,
                            action: { selectedPreset = preset }
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Bottom Actions
                VStack(spacing: 16) {
                    Button(action: applyPresetAndContinue) {
                        Text("Continue")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    
                    Button(action: { showCustomSettings = true }) {
                        Text("Customize Settings")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCustomSettings) {
            ActivityFeedSettingsView()
                .onDisappear {
                    markMigrationComplete()
                    onComplete()
                }
        }
    }
    
    private func applyPresetAndContinue() {
        Task {
            do {
                let userID = container.cloudKitManager.currentUserID ?? ""
                let settings: ActivityFeedSettings
                
                switch selectedPreset {
                case .minimal:
                    settings = .conservative(userID: userID)
                case .balanced:
                    settings = .balanced(userID: userID)
                case .social:
                    settings = .social(userID: userID)
                case .off:
                    var offSettings = ActivityFeedSettings(userID: userID)
                    offSettings.shareActivitiesToFeed = false
                    settings = offSettings
                }
                
                try await container.activitySharingSettingsService.saveSettings(settings)
                markMigrationComplete()
                onComplete()
            } catch {
                print("Failed to save sharing settings: \(error)")
                // Still mark as complete to avoid blocking the user
                markMigrationComplete()
                onComplete()
            }
        }
    }
    
    private func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: "hasSeenActivitySharingMigration")
    }
}

// MARK: - Preset Button

private struct PresetButton: View {
    let preset: ActivitySharingMigrationView.SharingPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(preset.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: preset.icon)
                        .font(.title2)
                        .foregroundColor(preset.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(preset.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color(.separator), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ActivitySharingMigrationView(onComplete: {})
        .environmentObject(DependencyContainer())
}
