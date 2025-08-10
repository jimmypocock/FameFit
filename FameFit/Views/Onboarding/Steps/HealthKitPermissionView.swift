//
//  HealthKitPermissionView.swift
//  FameFit
//
//  HealthKit permissions step of onboarding
//

import SwiftUI

struct HealthKitPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var permissionStatus: String = ""

    var body: some View {
        VStack(spacing: 30) {
            Text("PERMISSIONS")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("We need access to your workouts to track your fitness journey!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(
                    "This lets us:\n• Detect when you complete workouts\n• Track your progress\n• Award you Influencer XP for your efforts"
                )
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(20)

            Spacer()

            // Only show button if we don't have permission
            if !viewModel.hasHealthKitPermission {
                Button(action: {
                    viewModel.requestHealthKitPermissions()
                }, label: {
                    Text("Grant Access")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(15)
                })
                .disabled(viewModel.isLoading)
            }
            
            if !viewModel.hasHealthKitPermission {
                Button(action: {
                    viewModel.skipCurrentStep()
                }) {
                    Text("Continue Without Health Access")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text("You can enable this later in Settings")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            // Check permission status when view appears
            viewModel.checkHealthKitPermissions()
        }
        .onChange(of: viewModel.hasHealthKitPermission) { _, hasPermission in
            // If permission granted, immediately move to next step
            if hasPermission {
                viewModel.moveToNextStep()
            }
        }
    }
}