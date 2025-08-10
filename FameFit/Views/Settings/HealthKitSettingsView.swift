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
    
    @State private var isGranted: Bool
    @State private var isRequesting = false
    @State private var showingSystemSettings = false
    @State private var errorMessage: String?
    
    private let onPermissionChange: (Bool) -> Void
    
    init(hasPermission: Bool, onPermissionChange: @escaping (Bool) -> Void) {
        self._isGranted = State(initialValue: hasPermission)
        self.onPermissionChange = onPermissionChange
    }
    
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
                            
                            Text(isGranted ? "Access Granted" : "Access Not Granted")
                                .font(.body)
                                .foregroundColor(isGranted ? .green : .secondary)
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
                    if !isGranted {
                        Button(action: requestPermissions) {
                            HStack {
                                if isRequesting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Grant Access")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isRequesting)
                        
                        Text("If you previously denied access, you'll need to enable it in:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: openSystemSettings) {
                            Text("Settings > Privacy & Security > Health > FameFit")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Label("Access is enabled", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.headline)
                            
                            Text("To revoke access, go to:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: openSystemSettings) {
                                Text("Settings > Privacy & Security > Health > FameFit")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
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
        
        container.workoutObserver.requestHealthKitAuthorization { success, error in
            DispatchQueue.main.async {
                isRequesting = false
                
                if success {
                    isGranted = true
                    onPermissionChange(true)
                } else if let error = error {
                    // Check if it's a denial vs actual error
                    if case .healthKitAuthorizationDenied = error {
                        errorMessage = "Access was not granted. You can enable it in Settings."
                    } else {
                        errorMessage = error.localizedDescription
                    }
                } else {
                    errorMessage = "Access was not granted. You can enable it in Settings."
                }
                
                // Re-check actual status
                isGranted = container.workoutObserver.checkHealthKitAuthorization()
                onPermissionChange(isGranted)
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
    HealthKitSettingsView(hasPermission: false) { _ in }
        .environmentObject(DependencyContainer())
}