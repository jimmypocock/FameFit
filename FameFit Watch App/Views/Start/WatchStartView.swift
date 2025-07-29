//
//  WatchStartView.swift
//  FameFit Watch App
//
//  Created by Jimmy Pocock on 2025/07/02.
//

import HealthKit
import SwiftUI

struct WorkoutTypeItem: Identifiable {
    let id = UUID()
    let type: HKWorkoutActivityType

    var name: String {
        type.displayName
    }
}

struct WatchStartView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var navigationPath = NavigationPath()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared

    private let workoutTypes: [WorkoutTypeItem] = [
        WorkoutTypeItem(type: .cycling),
        WorkoutTypeItem(type: .running),
        WorkoutTypeItem(type: .walking)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // MARK: - LIST IN WATCH

            List(workoutTypes) { workoutType in
                Button {
                    workoutManager.selectedWorkout = workoutType.type
                    navigationPath.append(workoutType.type)
                } label: {
                    Text(workoutType.name)
                        .padding(
                            EdgeInsets(top: 15, leading: 5, bottom: 15, trailing: 5)
                        )
                }
                .accessibilityIdentifier(workoutType.name)
                .accessibilityLabel(workoutType.name)
            } //: LIST
            #if os(watchOS)
            .listStyle(.carousel)
            #endif
            .navigationBarTitle("FameFit")
            .navigationDestination(for: HKWorkoutActivityType.self) { _ in
                SessionPagingView()
            }
            .onAppear {
                workoutManager.requestAuthorization()
            }
            .onChange(of: workoutManager.showingSummaryView) { _, isShowing in
                if !isShowing, !navigationPath.isEmpty {
                    // Clear navigation when summary is dismissed
                    navigationPath.removeLast(navigationPath.count)
                }
            }
            .onChange(of: watchConnectivity.shouldStartWorkout) { _, shouldStart in
                if shouldStart, let workoutTypeRawValue = watchConnectivity.receivedWorkoutType {
                    // Convert raw value to HKWorkoutActivityType
                    if let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRawValue)) {
                        // Start the workout
                        workoutManager.selectedWorkout = workoutType
                        navigationPath.append(workoutType)
                        
                        // Reset the flag
                        DispatchQueue.main.async {
                            watchConnectivity.shouldStartWorkout = false
                            watchConnectivity.receivedWorkoutType = nil
                        }
                    }
                }
            }
        }
    }
}

struct WatchStartView_Previews: PreviewProvider {
    static var previews: some View {
        WatchStartView()
    }
}
