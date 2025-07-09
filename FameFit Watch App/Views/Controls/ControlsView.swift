//
//  ControlsView.swift
//  FameFit Watch App
//
//  Created by paige on 2021/12/11.
//

import SwiftUI

struct ControlsView: View {
    @EnvironmentObject var workoutManager: WorkoutManager

    var body: some View {
        HStack {
            VStack {
                Button {
                    workoutManager.endWorkout()
                } label: {
                    Image(systemName: "xmark")
                } //: BUTTON
                .tint(.red)
                .font(.title2)
                .accessibilityIdentifier("endWorkoutButton")

                Text("Quit") //: TEXT

            } //: VSTACK

            VStack {
                Button {
                    workoutManager.togglePause()
                } label: {
                    Image(systemName: workoutManager.isWorkoutRunning ? "pause" : "play")
                } //: BUTTON
                .tint(.yellow)
                .font(.title2)
                .accessibilityIdentifier(workoutManager.isWorkoutRunning ? "pauseButton" : "resumeButton")
                Text(workoutManager.isWorkoutRunning ? "Pause" : "Resume")
            } //: VSTACK

        } //: HSTACK
    }
}

struct ControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ControlsView()
    }
}
