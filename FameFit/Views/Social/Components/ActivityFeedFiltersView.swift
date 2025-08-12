//
//  ActivityFeedFiltersView.swift
//  FameFit
//
//  Filter controls for the activity feed
//

import SwiftUI

struct ActivityFeedFiltersView: View {
    let filters: ActivityFeedFilters
    let onApply: (ActivityFeedFilters) -> Void
    
    @State private var localFilters: ActivityFeedFilters
    @Environment(\.dismiss) private var dismiss
    
    init(filters: ActivityFeedFilters, onApply: @escaping (ActivityFeedFilters) -> Void) {
        self.filters = filters
        self.onApply = onApply
        _localFilters = State(initialValue: filters)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Activity Types") {
                    Toggle("Workouts", isOn: $localFilters.showWorkouts)
                    Toggle("Achievements", isOn: $localFilters.showAchievements)
                    Toggle("Level Ups", isOn: $localFilters.showLevelUps)
                    Toggle("Milestones", isOn: $localFilters.showMilestones)
                }
                
                Section("Time Range") {
                    Picker("Show Activities From", selection: $localFilters.timeRange) {
                        Text("Today").tag(ActivityFeedFilters.TimeRange.today)
                        Text("This Week").tag(ActivityFeedFilters.TimeRange.week)
                        Text("This Month").tag(ActivityFeedFilters.TimeRange.month)
                        Text("All Time").tag(ActivityFeedFilters.TimeRange.all)
                    }
                }
            }
            .navigationTitle("Filter Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply(localFilters)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ActivityFeedFiltersView(filters: ActivityFeedFilters()) { _ in
        // Preview action
    }
}