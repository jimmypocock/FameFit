//
//  MetricsView.swift
//  FameFit Watch App
//
//  Created by paige on 2021/12/11.
//

import SwiftUI

struct MetricsView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        // Use TimelineView for smooth updates without triggering navigation rebuilds
        TimelineView(.periodic(from: Date(), by: 0.01)) { _ in
            metricsContent
        }
    }
    
    private var metricsContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading) {
                // Show error if HealthKit failed
                if let error = workoutManager.workoutError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom)
                }


                // MARK: TIMELINE VIEW, Timer

                ElapsedTimeView(
                    elapsedTime: workoutManager.displayElapsedTime,
                    showSubseconds: workoutManager.isWorkoutRunning
                )
                .foregroundColor(.yellow)

                // MARK: - MEASUREMENT

                Text(
                    Measurement(
                        value: workoutManager.activeEnergy,
                        unit: UnitEnergy.kilocalories
                    )
                    .formatted(
                        .measurement(
                            width: .abbreviated,
                            usage: .workout,
                            numberFormatStyle:
                            FloatingPointFormatStyle
                                .number
                                .precision(
                                    .fractionLength(0)
                                )
                        )
                    )
                ) // CALORIES TEXT

                Text(
                    workoutManager.heartRate
                        .formatted(
                            .number
                                .precision(
                                    .fractionLength(0)
                                )
                        )
                        +
                        " bpm"
                ) // BPM TEXT

                Text(
                    Measurement(
                        value: workoutManager.distance,
                        unit: UnitLength.meters
                    )
                    .formatted(
                        .measurement(
                            width: .abbreviated,
                            usage: .road
                        )
                    )
                ) // ROAD TEXT
            } //: VSTACK - PAGE WRAPPER
        } //: SCROLLVIEW
        .font(
            .system(.title, design: .rounded)
                .monospacedDigit()
                .lowercaseSmallCaps()
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .ignoresSafeArea(edges: .bottom)
        .scenePadding()
    }
}

struct MetricsView_Previews: PreviewProvider {
    static var previews: some View {
        MetricsView()
    }
}

// MARK: TIMELINE SCHEDULE FOR TIMER

private struct MetricsTimelinesSchedule: TimelineSchedule {
    var startDate: Date
    init(from startDate: Date) {
        self.startDate = startDate
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> PeriodicTimelineSchedule.Entries {
        PeriodicTimelineSchedule(
            from: self.startDate,
            by: mode == .lowFrequency ? 1.0 : 1.0 / 30.0
        )
        .entries(
            from: startDate,
            mode: mode
        )
    }
}
