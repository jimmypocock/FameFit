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
                Text("Sync").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content
            switch selectedTab {
            case 0:
                // Start tab
                WorkoutStartView()
            case 1:
                // History tab
                WorkoutHistoryView()
            case 2:
                // Sync tab
                WorkoutSyncTabView()
            default:
                WorkoutStartView()
            }
        }
    }
}

#Preview {
    WorkoutsContainerView()
        .environment(\.dependencyContainer, DependencyContainer())
}
