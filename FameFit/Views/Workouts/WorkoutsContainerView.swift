//
//  WorkoutsContainerView.swift
//  FameFit
//
//  Container view for Start/History workout tabs
//

import SwiftUI

struct WorkoutsContainerView: View {
    @State private var selectedTab = 0 // Default to Start tab
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Workout View", selection: $selectedTab) {
                Text("Start").tag(0)
                Text("History").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content
            if selectedTab == 0 {
                // Start tab
                WorkoutStartView()
            } else {
                // History tab
                WorkoutHistoryView()
            }
        }
    }
}

#Preview {
    WorkoutsContainerView()
        .environment(\.dependencyContainer, DependencyContainer())
}
