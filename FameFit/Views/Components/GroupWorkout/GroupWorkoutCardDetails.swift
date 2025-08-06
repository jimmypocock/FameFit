//
//  GroupWorkoutDetails.swift
//  FameFit
//
//  Details section with duration, participants count, and tags
//

import SwiftUI

struct GroupWorkoutCardDetails: View {
    let groupWorkout: GroupWorkout

    var body: some View {
        HStack(spacing: 16) {
            // Tags (if available)
            if !groupWorkout.tags.isEmpty {
                ForEach(groupWorkout.tags.prefix(3), id: \.self) { tag in
                    GroupWorkoutDetailPill(
                        icon: "tag",
                        value: tag,
                        color: .purple
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}