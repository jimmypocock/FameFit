//
//  SummaryView.swift
//  FameFit Watch App
//
//  Created by paige on 2021/12/11.
//

import HealthKit
import SwiftUI

struct SummaryView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var accountService: AccountVerificationService
    @EnvironmentObject private var navigationCoordinator: WatchNavigationCoordinator
    @EnvironmentObject private var container: DependencyContainer
    
    // Use the SummaryViewModel from container
    private var summaryViewModel: SummaryViewModel {
        container.summaryViewModel
    }

    // MARK: DISMISS ENVIRONMENT VARIABLE

    @Environment(\.dismiss)
    private var dismiss
    /*
     Button("Done") {
     dismiss()
     }
     */

    // MARK: Formatter

    @State private var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    var body: some View {
        if let workout = workoutManager.workout {
            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    // Motivational message at the top
                    Text(SummaryMessages.getMessage(duration: workout.duration))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 8)
                    
                    SummaryMetricView(
                        title: "Total Time",
                        value: durationFormatter.string(from: workout.duration) ?? ""
                    )
                    .accentColor(.yellow)

                    SummaryMetricView(
                        title: "Total Distance",
                        value: Measurement(
                            value: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
                            unit: UnitLength.meters
                        ).formatted(
                            .measurement(width: .abbreviated, usage: .road)
                        )
                    )
                    .accentColor(.green)

                    SummaryMetricView(
                        title: "Total Energy",
                        value: Measurement(
                            value: workoutManager.activeEnergy > 0 ? workoutManager.activeEnergy : {
                                if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                                   let energy = workoutManager.workout?.statistics(for: energyType)?.sumQuantity() {
                                    energy.doubleValue(for: .kilocalorie())
                                } else {
                                    0
                                }
                            }(), unit: UnitEnergy.kilocalories
                        ).formatted(
                            .measurement(
                                width: .abbreviated,
                                usage: .workout,
                                numberFormatStyle:
                                FloatingPointFormatStyle
                                    .number
                                    .precision(.fractionLength(0))
                            )
                        )
                    )
                    .accentColor(.pink)

                    SummaryMetricView(
                        title: "Avg. Heart Rate",
                        value: workoutManager.averageHeartRate
                            .formatted(
                                .number
                                    .precision(.fractionLength(0))
                            )
                            +
                            " bpm"
                    )
                    .accentColor(.red)

                    // Show account-specific message
                    if !accountService.accountStatus.hasAccount {
                        // No account - show prompt
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("No Account")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            Text("Create account on iPhone to earn XP!")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }


                    // Activity Rings
                    VStack {
                        Text("Activity Rings")
                            .font(.headline)
                        ActivityRingsView(heatlStore: HKHealthStore())
                            .frame(width: 75, height: 75)
                    }
                    .padding(.vertical, 8)

                    Button("Done") {
                        // Use coordinator to properly handle navigation
                        navigationCoordinator.dismissSummary()
                    }
                } //: VSTACK
                .scenePadding()
            } //: SCROLLVIEW
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        navigationCoordinator.dismissSummary()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                FameFitLogger.debug("📍 SummaryView: onAppear called", category: FameFitLogger.sync)
                
                // Load workout summary and trigger sync to iPhone
                if let workout = workoutManager.workout {
                    Task {
                        await summaryViewModel.loadWorkoutSummary(workout)
                    }
                }
            }
            .onDisappear {
                FameFitLogger.debug("📍 SummaryView: onDisappear called", category: FameFitLogger.sync)
                // Clean up summary view model
                summaryViewModel.dismiss()
                // Reset workout state when summary is dismissed
                workoutManager.resetWorkout()
            }
        }
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView()
    }
}

struct SummaryMetricView: View {
    var title: String
    var value: String

    var body: some View {
        Text(title)
        Text(value)
            .font(
                .system(.title2, design: .rounded)
                    .lowercaseSmallCaps()
            )
            .foregroundColor(.accentColor)
        Divider()
    }
}
