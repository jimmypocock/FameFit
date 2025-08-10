//
//  HealthKitPermissionView.swift
//  FameFit
//
//  HealthKit permissions step of onboarding
//

import SwiftUI

struct HealthKitPermissionView: View {
    @ObservedObject var viewModel: OnboardingViewModel

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

            if viewModel.hasHealthKitPermission {
                Text("✅ Access Granted!")
                    .foregroundColor(.green)
                    .font(.headline)
            }
            
            if !viewModel.hasHealthKitPermission {
                Button(action: {
                    viewModel.skipCurrentStep()
                }) {
                    Text("Skip for now")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}