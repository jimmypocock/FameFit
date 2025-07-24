//
//  SessionPagingView.swift
//  FameFit Watch App
//
//  Created by paige on 2021/12/11.
//

import SwiftUI
import HealthKit
#if os(watchOS)
import WatchKit
#endif

// MARK: - TABVIEW WITH ENUM
struct SessionPagingView: View {
    // MARK: isLuminanceReduced
    @Environment(\.isLuminanceReduced)
    var isLuminanceReduced
    /*
     .tabViewStyle(
     PageTabViewStyle(indexDisplayMode: isLuminanceReduced ? .never : .automatic)
     )
     .onChange(of: isLuminanceReduced) { _ in
     dispayMetricsView()
     }
     */

    @EnvironmentObject private var workoutManager: WorkoutManager
    @State private var selection: Tab = .metrics

    enum Tab {
        case controls, metrics, nowPlaying
    }

    var body: some View {
        TabView(selection: $selection) {
            ControlsView().tag(Tab.controls)
            MetricsView().tag(Tab.metrics)
            // MARK: NowPlayingView is provided by WatchKit
            #if os(watchOS)
            NowPlayingView().tag(Tab.nowPlaying)
            #endif
        }
        .navigationTitle(getWorkoutName(for: workoutManager.selectedWorkout))
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(selection == .nowPlaying)
        .tabViewStyle(
            PageTabViewStyle(indexDisplayMode: isLuminanceReduced ? .never : .automatic)
        )
        .onAppear {
            if let workout = workoutManager.selectedWorkout {
                workoutManager.startWorkout(workoutType: workout)
            }
        }
    }


    private func getWorkoutName(for workoutType: HKWorkoutActivityType?) -> String {
        guard let workoutType = workoutType else { return "" }
        return workoutType.displayName
    }
}

struct SessionPagingView_Previews: PreviewProvider {
    static var previews: some View {
        SessionPagingView()
    }
}
