//
//  ContentView.swift
//  WWDC_WatchApp WatchKit Extension
//
//  Created by paige on 2021/12/11.
//

import SwiftUI
import HealthKit

struct StartView: View {
    
    @EnvironmentObject var workoutManager: WorkoutManager
    private var workoutTypes: [HKWorkoutActivityType] = [.cycling, .running, .walking]
    
    var body: some View {
        // MARK: - LIST IN WATCH 
        List(workoutTypes) { workoutType in
            NavigationLink(
                workoutType.name,
                destination: SessionPagingView(),
                tag: workoutType,
                selection: $workoutManager.selectedWorkout
            )
                .padding(
                    EdgeInsets(top: 15, leading: 5, bottom: 15, trailing: 5)
                ) //: NAVIGATION LINK
        } //: LIST
        .listStyle(.carousel)
        .navigationBarTitle("FameFit")
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

struct StartView_Previews: PreviewProvider {
    static var previews: some View {
        StartView()
    }
}

// MARK: EXTENSION FOR MAPPING ENUMS VALUES WITH NAME
extension HKWorkoutActivityType: Identifiable {
    
    public var id: UInt {
        rawValue
    }
    
    var name: String {
        switch self {
        case .running:
            return "Run"
        case .cycling:
            return "Bike"
        case .walking:
            return "Walk"
        default:
            return ""
        }
    }
    
}
