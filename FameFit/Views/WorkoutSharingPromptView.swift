//
//  WorkoutSharingPromptView.swift
//  FameFit
//
//  Prompt for sharing workout to social feed with privacy controls
//

import HealthKit
import SwiftUI

struct WorkoutSharingPromptView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    let workoutHistory: WorkoutHistoryItem
    let onShare: (WorkoutPrivacy, Bool) -> Void

    @State private var selectedPrivacy: WorkoutPrivacy = .friendsOnly
    @State private var includeDetails = true
    @State private var isSharing = false
    @State private var showError = false
    @State private var errorMessage = ""

    // Load user's privacy settings
    @State private var privacySettings = WorkoutPrivacySettings()

    private var workoutType: HKWorkoutActivityType? {
        HKWorkoutActivityType.from(storageKey: workoutHistory.workoutType)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Workout Preview
                workoutPreview

                // Privacy Controls
                privacyControlsSection

                // Detail Sharing Toggle
                detailSharingSection

                Spacer()

                // Action Buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadPrivacySettings()
        }
        .alert("Sharing Error", isPresented: $showError) {
            Button("OK") {
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Great Workout!")
                .font(.title2)
                .fontWeight(.bold)

            Text("Share your achievement with friends?")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var workoutPreview: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: workoutIcon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workoutDisplayName)
                        .font(.headline)
                        .fontWeight(.medium)

                    Text(workoutDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if workoutHistory.followersEarned > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(workoutHistory.followersEarned)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                        Text("XP")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private var privacyControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Who can see this?")
                .font(.headline)

            ForEach(WorkoutPrivacy.allCases, id: \.self) { privacy in
                // Filter out public for users who can't share publicly
                if privacy == .public, !privacySettings.allowPublicSharing {
                    EmptyView()
                } else {
                    privacyOptionView(privacy)
                }
            }
        }
    }

    private func privacyOptionView(_ privacy: WorkoutPrivacy) -> some View {
        Button(action: {
            selectedPrivacy = privacy
        }) {
            HStack(spacing: 16) {
                Image(systemName: privacy.icon)
                    .font(.title3)
                    .foregroundColor(selectedPrivacy == privacy ? .blue : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(privacy.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(privacy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if selectedPrivacy == privacy {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedPrivacy == privacy ? Color.blue : Color.clear, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedPrivacy == privacy ? Color.blue.opacity(0.05) : Color(.systemGray6))
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var detailSharingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Include workout details", isOn: $includeDetails)
                .font(.body)

            Text("Share duration, calories, and distance")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .disabled(!privacySettings.allowDataSharing)
        .opacity(privacySettings.allowDataSharing ? 1.0 : 0.6)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: shareWorkout) {
                HStack {
                    if isSharing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("Share Workout")
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isSharing)

            Button("Not this time") {
                dismiss()
            }
            .font(.body)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Properties

    private var workoutIcon: String {
        workoutType?.iconName ?? "figure.run"
    }

    private var workoutDisplayName: String {
        workoutHistory.workoutType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var workoutDuration: String {
        let minutes = Int(workoutHistory.duration / 60)
        let seconds = Int(workoutHistory.duration.truncatingRemainder(dividingBy: 60))

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Actions

    private func loadPrivacySettings() {
        // In a real implementation, load from UserDefaults or CloudKit
        // For now, use defaults
        if let workoutType {
            selectedPrivacy = privacySettings.privacyLevel(for: workoutType)
        }

        // Respect data sharing preferences
        if !privacySettings.allowDataSharing {
            includeDetails = false
        }
    }

    private func shareWorkout() {
        isSharing = true

        Task {
            do {
                // Validate privacy level
                let effectivePrivacy = privacySettings.effectivePrivacy(for: workoutType ?? .other)
                let finalPrivacy = min(selectedPrivacy, effectivePrivacy)

                try await container.activityFeedService.postWorkoutActivity(
                    workoutHistory: workoutHistory,
                    privacy: finalPrivacy,
                    includeDetails: includeDetails && privacySettings.allowDataSharing
                )

                await MainActor.run {
                    onShare(finalPrivacy, includeDetails)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    // Helper to use most restrictive privacy level
    private func min(_ privacy1: WorkoutPrivacy, _ privacy2: WorkoutPrivacy) -> WorkoutPrivacy {
        let order: [WorkoutPrivacy] = [.private, .friendsOnly, .public]
        let index1 = order.firstIndex(of: privacy1) ?? 0
        let index2 = order.firstIndex(of: privacy2) ?? 0
        return order[Swift.min(index1, index2)]
    }
}

// Extension removed - using unified HKWorkoutActivityType+Extensions.swift

// MARK: - Preview

#Preview {
    WorkoutSharingPromptView(
        workoutHistory: WorkoutHistoryItem(
            id: UUID(),
            workoutType: "running",
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            duration: 1800,
            totalEnergyBurned: 250,
            totalDistance: 3.2,
            averageHeartRate: 140,
            followersEarned: 25,
            xpEarned: 25,
            source: "FameFit"
        ),
        onShare: { privacy, includeDetails in
            print("Shared with privacy: \(privacy), details: \(includeDetails)")
        }
    )
    .environment(\.dependencyContainer, DependencyContainer())
}
