//
//  FameFitApp.swift
//  FameFit Watch App
//
//  Created by Jimmy Pocock on 6/27/25.
//

import SwiftUI

@main
struct FameFitApp: App {
    @StateObject private var workoutManager = WorkoutManager()

    init() {
        // Initialize WatchConnectivity early to be ready for messages
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            WatchStartView()
                .sheet(isPresented: $workoutManager.showingSummaryView) {
                    SummaryView()
                }
                .environmentObject(workoutManager)
        }
    }
}
