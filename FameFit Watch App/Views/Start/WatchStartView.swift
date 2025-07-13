//
//  WatchStartView.swift
//  FameFit Watch App
//
//  Created by Jimmy Pocock on 2025/07/02.
//

import SwiftUI
import HealthKit

struct WorkoutTypeItem: Identifiable {
    let id = UUID()
    let type: HKWorkoutActivityType

    var name: String {
        switch type {
        case .running:
            return "Run"
        case .cycling:
            return "Bike"
        case .walking:
            return "Walk"
        default:
            return "Workout"
        }
    }
}

struct WatchStartView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var navigationPath = NavigationPath()
    
    private let workoutTypes: [WorkoutTypeItem] = [
        WorkoutTypeItem(type: .cycling),
        WorkoutTypeItem(type: .running),
        WorkoutTypeItem(type: .walking)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // MARK: - LIST IN WATCH
            List(workoutTypes) { workoutType in
                Button(action: {
                    workoutManager.selectedWorkout = workoutType.type
                    navigationPath.append(workoutType.type)
                }) {
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
                if !isShowing && !navigationPath.isEmpty {
                    // Clear navigation when summary is dismissed
                    navigationPath.removeLast(navigationPath.count)
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
