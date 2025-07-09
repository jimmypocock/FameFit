//
//  SummaryView.swift
//  FameFit Watch App
//
//  Created by paige on 2021/12/11.
//

import SwiftUI
import HealthKit

struct SummaryView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager

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
                                    return energy.doubleValue(for: .kilocalorie())
                                } else {
                                    return 0
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

                    // Show FameFit end message or achievement
                    if !workoutManager.currentMessage.isEmpty {
                        Text(workoutManager.currentMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    }
                    
                    // Achievement Progress
                    if !workoutManager.achievementManager.unlockedAchievements.isEmpty {
                        let progress = workoutManager.achievementManager.getAchievementProgress()
                        VStack(alignment: .leading) {
                            Text("Achievements")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("\(progress.unlocked) of \(progress.total) unlocked")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                        Divider()
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
                        dismiss()
                    }
                } //: VSTACK
                .scenePadding()
            } //: SCROLLVIEW
            .navigationTitle("Well, Well, Well...")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
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
