//
//  SummaryView.swift
//  WWDC_WatchApp WatchKit Extension
//
//  Created by paige on 2021/12/11.
//

import SwiftUI
import HealthKit

struct SummaryView: View {
    
    @EnvironmentObject private var workoutManager: WorkoutManager
    
    // MARK: DISMISS ENVIRONMENT VARIABLE
    @Environment(\.dismiss) private var dismiss
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
        
        if workoutManager.workout == nil {
            // MARK: PROGRES VIEW
            ProgressView("Saving workout")
                .navigationBarHidden(true)
        } else {
            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    
                    SummaryMetricView(
                        title: "Total Time",
                        value: durationFormatter.string(from: workoutManager.workout?.duration ?? 0.0) ?? ""
                    )
                    .accentColor(.yellow)
                    
                    SummaryMetricView(
                        title: "Total Distance",
                        value: Measurement(
                            value: workoutManager.workout?.totalDistance?.doubleValue(for: .meter()) ?? 0, unit: UnitLength.meters
                        ).formatted(
                            .measurement(width: .abbreviated, usage: .road)
                        )
                    )
                    .accentColor(.green)
                    
                    SummaryMetricView(
                        title: "Total Energy",
                        value: Measurement(
                            value: workoutManager.workout?.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0, unit: UnitEnergy.kilocalories
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
                    
                    Text("Activity Rings")
                    ActivityRingsView(heatlStore: HKHealthStore())
                        .frame(width: 50, height: 50)
                    
                    // MARK: - Achievement Progress
                    if workoutManager.achievementManager.unlockedAchievements.count > 0 {
                        let progress = workoutManager.achievementManager.getAchievementProgress()
                        VStack(alignment: .leading) {
                            Text("Achievements")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Text("\(progress.unlocked) of \(progress.total) unlocked")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            if let recentAchievement = workoutManager.achievementManager.recentAchievement {
                                Text("🏆 \(recentAchievement.title)")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                    
                    // MARK: - FameFit Final Message
                    if !workoutManager.currentMessage.isEmpty {
                        Text(workoutManager.currentMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    }
                    
                    Button("Done") {
                        dismiss()
                    }
                    
                } //: VSTACK
                .scenePadding()
            } //: SCROLLVIEW
            .navigationTitle("Well, Well, Well...")
            .navigationBarTitleDisplayMode(.inline)
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
