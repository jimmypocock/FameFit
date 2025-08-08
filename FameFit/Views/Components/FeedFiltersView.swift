//
//  ActivityFeedFiltersView.swift
//  FameFit
//
//  Feed filters view component for filtering activity feeds
//

import SwiftUI

struct ActivityFeedFiltersView: View {
    @Environment(\.dismiss) var dismiss
    @State private var filters: ActivityFeedFilters
    let onApply: (ActivityFeedFilters) -> Void

    init(filters: ActivityFeedFilters, onApply: @escaping (ActivityFeedFilters) -> Void) {
        _filters = State(initialValue: filters)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity Types") {
                    Toggle("Workouts", isOn: $filters.showWorkouts)
                    Toggle("Achievements", isOn: $filters.showAchievements)
                    Toggle("Level Ups", isOn: $filters.showLevelUps)
                    Toggle("Milestones", isOn: $filters.showMilestones)
                }

                Section("Time Range") {
                    Picker("Show activities from", selection: $filters.timeRange) {
                        ForEach(ActivityFeedFilters.TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
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
                        onApply(filters)
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
}

#Preview {
    ActivityFeedFiltersView(filters: ActivityFeedFilters()) { _ in }
}
