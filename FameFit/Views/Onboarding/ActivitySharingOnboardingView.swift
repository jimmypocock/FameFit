//
//  ActivitySharingOnboardingView.swift
//  FameFit
//
//  Activity sharing configuration step in onboarding
//

import SwiftUI

struct ActivitySharingOnboardingView: View {
    @Binding var onboardingStep: Int
    @Environment(\.dependencyContainer) var container
    
    @State private var selectedPreset: ActivityFeedSettings.SharingPreset = .balanced
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SHARE YOUR JOURNEY")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.badge.clock")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .symbolRenderingMode(.hierarchical)
                
                Text("Automatic Activity Sharing")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                
                Text("Your workouts can automatically appear in your followers' feeds, building your influence while you exercise!")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            
            // Preset Options
            VStack(spacing: 12) {
                presetOption(.minimal, "Private Mode", "Share only long workouts with friends", "lock.shield")
                presetOption(.balanced, "Balanced", "Share most workouts with followers", "checkmark.shield")
                presetOption(.social, "Social Butterfly", "Share everything publicly", "person.3.fill")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Info text
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                Text("You can change this anytime in settings")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.7))
            
            // Continue button
            Button(action: saveSettingsAndContinue) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Continue")
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
            }
            .padding(.horizontal)
            .disabled(isLoading)
        }
        .padding(.vertical)
        .alert("Setup Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func presetOption(_ preset: ActivityFeedSettings.SharingPreset, _ title: String, _ description: String, _ icon: String) -> some View {
        Button(action: { selectedPreset = preset }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                Spacer()
                
                if selectedPreset == preset {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedPreset == preset ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedPreset == preset ? Color.white : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func saveSettingsAndContinue() {
        isLoading = true
        
        Task {
            do {
                let settings: ActivityFeedSettings
                
                switch selectedPreset {
                case .minimal:
                    settings = .conservative
                case .balanced:
                    settings = .balanced
                case .social:
                    settings = .social
                case .custom:
                    // Shouldn't happen in onboarding
                    settings = .balanced
                }
                
                try await container.activitySharingSettingsService.saveSettings(settings)
                
                await MainActor.run {
                    isLoading = false
                    // Move to game mechanics (next step)
                    onboardingStep = 5
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save sharing preferences. Please try again."
                    showError = true
                }
            }
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.purple, Color.blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        ActivitySharingOnboardingView(onboardingStep: .constant(4))
            .environment(\.dependencyContainer, DependencyContainer())
    }
}