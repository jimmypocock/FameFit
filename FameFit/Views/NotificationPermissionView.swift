//
//  NotificationPermissionView.swift
//  FameFit
//
//  View for requesting push notification permissions
//

import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencyContainer) private var container
    
    @State private var isRequesting = false
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showError = false
    @State private var errorMessage = ""
    
    var onPermissionGranted: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .symbolRenderingMode(.hierarchical)
                
                Text("Stay Connected")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Get notified when friends kudos your workouts, follow you, or when you unlock achievements!")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Benefits list
            VStack(alignment: .leading, spacing: 16) {
                BenefitRow(
                    icon: "heart.fill",
                    title: "Workout Kudos",
                    description: "Know when friends cheer for your workouts"
                )
                
                BenefitRow(
                    icon: "person.2.fill",
                    title: "New Followers",
                    description: "Get notified when someone follows you"
                )
                
                BenefitRow(
                    icon: "trophy.fill",
                    title: "Achievements",
                    description: "Celebrate your fitness milestones"
                )
                
                BenefitRow(
                    icon: "bell.slash",
                    title: "Full Control",
                    description: "Customize which notifications you receive"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: requestPermission) {
                    if isRequesting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Enable Notifications")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isRequesting || permissionStatus == .authorized)
                
                if permissionStatus == .notDetermined {
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                if permissionStatus == .denied {
                    Button("Open Settings") {
                        openSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .alert("Notification Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
        .task {
            await checkCurrentStatus()
        }
    }
    
    // MARK: - Private Methods
    
    private func checkCurrentStatus() async {
        let status = container.apnsManager.notificationAuthorizationStatus
        await MainActor.run {
            self.permissionStatus = status
        }
    }
    
    private func requestPermission() {
        isRequesting = true
        
        Task {
            do {
                let granted = try await container.apnsManager.requestNotificationPermissions()
                
                await MainActor.run {
                    isRequesting = false
                    
                    if granted {
                        permissionStatus = .authorized
                        onPermissionGranted?()
                        
                        // Give a moment for the UI to update
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismiss()
                        }
                    } else {
                        permissionStatus = .denied
                        errorMessage = "Notifications were not enabled. You can enable them later in Settings."
                        showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Benefit Row

private struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationPermissionView()
        .environment(\.dependencyContainer, DependencyContainer())
}