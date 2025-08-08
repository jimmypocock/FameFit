//
//  HealthKitOnboardingView.swift
//  FameFit
//
//  HealthKit permissions request step
//

import HealthKit
import SwiftUI

struct HealthKitOnboardingView: View {
    @Binding var onboardingStep: Int
    @Binding var healthKitAuthorized: Bool
    @EnvironmentObject var workoutObserver: WorkoutObserver
    @State private var isRequesting = false
    @State private var authError: String?

    private let healthPermissions = [
        ("Heart Rate", "heart.fill", "Track your heart rate during workouts"),
        ("Active Calories", "flame.fill", "See calories burned"),
        ("Workout Distance", "figure.run", "Track distance covered"),
        ("Activity Summary", "chart.bar.fill", "View your daily activity")
    ]

    var body: some View {
        VStack(spacing: 30) {
            Text("HEALTH PERMISSIONS")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("We need access to your health data to track your workouts and calculate your XP")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Permissions list
            VStack(alignment: .leading, spacing: 15) {
                ForEach(healthPermissions, id: \.0) { permission in
                    HStack(spacing: 15) {
                        Image(systemName: permission.1)
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(permission.0)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(permission.2)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button(action: requestHealthKitPermission) {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "heart.text.square.fill")
                        Text("Grant Access")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(15)
            }
            .disabled(isRequesting || healthKitAuthorized)
            .padding(.horizontal, 40)

            if healthKitAuthorized {
                Label("Access Granted!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
            }

            if let error = authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .onAppear {
            checkHealthKitAuthorization()
        }
    }

    private func checkHealthKitAuthorization() {
        let healthStore = HKHealthStore()
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.activitySummaryType()
        ]

        // Check if already authorized
        var isAuthorized = true
        for type in typesToRead {
            if healthStore.authorizationStatus(for: type) != .sharingAuthorized {
                isAuthorized = false
                break
            }
        }

        healthKitAuthorized = isAuthorized
        if isAuthorized {
            // Auto-advance if already authorized
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                onboardingStep = 3
            }
        }
    }

    private func requestHealthKitPermission() {
        isRequesting = true
        authError = nil

        workoutObserver.requestHealthKitAuthorization { authorized, error in
            DispatchQueue.main.async {
                isRequesting = false
                healthKitAuthorized = authorized

                if let error = error {
                    authError = "Failed to authorize HealthKit: \(error.localizedDescription)"
                } else if authorized {
                    // Move to next step
                    withAnimation {
                        onboardingStep = 3
                    }
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
        
        HealthKitOnboardingView(onboardingStep: .constant(2), healthKitAuthorized: .constant(false))
            .environmentObject(WorkoutObserver(cloudKitManager: CloudKitManager(), healthKitService: RealHealthKitService()))
    }
}
