//
//  GroupWorkoutHeader.swift
//  FameFit
//
//  Header component for group workout card with status and timing
//

import SwiftUI

struct GroupWorkoutHeader: View {
    let groupWorkout: GroupWorkout
    @Binding var isAnimating: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            GroupWorkoutStatusIndicator(
                status: groupWorkout.status,
                isAnimating: $isAnimating
            )

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(groupWorkout.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    if !groupWorkout.isPublic {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: GroupWorkoutTypeProvider.icon(for: groupWorkout.workoutType))
                        .font(.system(size: 16))
                        .foregroundColor(.blue)

                    Text(GroupWorkoutTypeProvider.displayName(for: groupWorkout.workoutType))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    if groupWorkout.status == .active {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.green)
                            .opacity(isAnimating ? 0.3 : 1.0)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                                    isAnimating = true
                                }
                            }

                        Text("LIVE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                }

                // Description (if provided)
                if !groupWorkout.description.isEmpty {
                    Text(groupWorkout.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Timing info
            GroupWorkoutTimingInfo(groupWorkout: groupWorkout)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}