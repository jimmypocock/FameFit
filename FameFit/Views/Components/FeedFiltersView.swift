//
//  FeedFiltersView.swift
//  FameFit
//
//  Feed filters view component for filtering activity feeds
//

import SwiftUI

struct FeedFiltersView: View {
    @Environment(\.dismiss) var dismiss
    @State private var filters: FeedFilters
    let onApply: (FeedFilters) -> Void

    init(filters: FeedFilters, onApply: @escaping (FeedFilters) -> Void) {
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
                        ForEach(FeedFilters.TimeRange.allCases, id: \.self) { range in
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
    FeedFiltersView(filters: FeedFilters()) { _ in }
}