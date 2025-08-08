//
//  NavigationDebugView.swift
//  FameFit
//
//  Debug view to visualize navigation paths and history
//

import SwiftUI

struct NavigationDebugView: View {
    @Environment(\.navigationCoordinator) private var navigationCoordinator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            if let coordinator = navigationCoordinator {
                List {
                    Section("Current Tab") {
                        HStack {
                            Text("Selected Tab")
                            Spacer()
                            Text("\(tabName(coordinator.selectedTab))")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Section("Navigation Paths") {
                        pathInfo("Group Workouts", count: pathCount(coordinator.groupWorkoutsPath))
                        pathInfo("Challenges", count: pathCount(coordinator.challengesPath))
                        pathInfo("Workouts", count: pathCount(coordinator.workoutsPath))
                        pathInfo("Profile", count: pathCount(coordinator.profilePath))
                    }
                    
                    Section("Test Navigation") {
                        Button("Go to Group Workouts Tab") {
                            coordinator.selectedTab = 3
                            dismiss()
                        }
                        
                        Button("Deep Link to Test Workout") {
                            coordinator.navigateToGroupWorkoutDetail(id: "test-workout-123")
                            dismiss()
                        }
                        
                        Button("Clear All Navigation Paths") {
                            coordinator.clearAllPaths()
                        }
                        .foregroundColor(.red)
                    }
                
                Section("Deep Link Examples") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("famefit://groupworkout/[workout-id]")
                            .font(.system(.caption, design: .monospaced))
                        Text("famefit://profile/[user-id]")
                            .font(.system(.caption, design: .monospaced))
                        Text("famefit://challenge/[challenge-id]")
                            .font(.system(.caption, design: .monospaced))
                        Text("famefit://workout/[workout-id]")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                }
            .navigationTitle("Navigation Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            } else {
                Text("Navigation Coordinator not available")
                    .foregroundColor(.secondary)
                    .navigationTitle("Navigation Debug")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    private func pathInfo(_ name: String, count: Int) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text("\(count) items")
                .foregroundColor(.secondary)
        }
    }
    
    private func pathCount(_ path: NavigationPath) -> Int {
        // NavigationPath doesn't expose count directly in SwiftUI
        // This is a placeholder - in real app you might track this separately
        return 0
    }
    
    private func tabName(_ index: Int) -> String {
        switch index {
        case 0: "Home"
        case 1: "Search"
        case 2: "Workouts"
        case 3: "Group"
        case 4: "Challenges"
        default: "Unknown"
        }
    }
}

#Preview {
    NavigationDebugView()
}
