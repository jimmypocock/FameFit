//
//  HealthKitSettingsView.swift
//  FameFit
//
//  Settings view for managing HealthKit permissions
//

import SwiftUI
import HealthKit

struct HealthKitSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container
    
    @State private var isRequesting = false
    @State private var showingSystemSettings = false
    @State private var errorMessage: String?
    @State private var requestSucceeded = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header explanation
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading) {
                            Text("Health Access")
                                .font(.title2)
                                .bold()
                            
                            Text("Manage workout data access")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Text("FameFit uses your workout data to:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        bulletPoint("Automatically detect when you complete workouts")
                        bulletPoint("Track your fitness progress over time")
                        bulletPoint("Award you XP and achievements for your efforts")
                        bulletPoint("Show your activity to friends (based on privacy settings)")
                    }
                }
                .padding()
                
                Spacer()
                
                // Action section
                VStack(spacing: 16) {
                    if requestSucceeded {
                        VStack(spacing: 12) {
                            Label("Request Completed", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.headline)
                            
                            Text("If you granted access, your workouts will now be tracked. If not, you can grant access in Settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    Button(action: requestPermissions) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Text(requestSucceeded ? "Request Access Again" : "Grant Access")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isRequesting)
                    
                    Text("To manage access directly:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: openSystemSettings) {
                        Text("Settings > Privacy & Security > Health > FameFit")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Health Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
                .padding(.top, 2)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Actions
    
    private func requestPermissions() {
        isRequesting = true
        errorMessage = nil
        requestSucceeded = false
        
        container.workoutObserver.requestHealthKitAuthorization { success, error in
            DispatchQueue.main.async {
                isRequesting = false
                
                if let error = error {
                    // Check if it's a denial vs actual error
                    if case .healthKitAuthorizationDenied = error {
                        // User was shown the dialog but we don't know what they selected
                        requestSucceeded = true
                        errorMessage = nil
                    } else {
                        errorMessage = error.localizedDescription
                        requestSucceeded = false
                    }
                } else {
                    // Request completed successfully (dialog was shown)
                    requestSucceeded = true
                    errorMessage = nil
                }
            }
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    HealthKitSettingsView()
        .environment(\.dependencyContainer, DependencyContainer())
}