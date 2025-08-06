//
//  GroupWorkoutHeader.swift
//  FameFit
//
//  Header component for group workout card with status and timing
//

import SwiftUI

struct GroupWorkoutCardHeader: View {
    let groupWorkout: GroupWorkout
    @Binding var isAnimating: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(groupWorkout.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Image(systemName: GroupWorkoutTypeProvider.icon(for: groupWorkout.workoutType))
                        .font(.system(size: 16))
                        .foregroundColor(secondaryTextColor)

                    Text(GroupWorkoutTypeProvider.displayName(for: groupWorkout.workoutType))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
                
                // Time display under workout type
                Text(statusTimeText)
                    .font(.caption)
                    .foregroundColor(statusTimeColor)
            }

            Spacer()

            // Public/Private indicator with participants count
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: groupWorkout.isPublic ? "person.2" : "lock")
                        .font(.system(size: 11))
                    Text(groupWorkout.isPublic ? "Public" : "Private")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(groupWorkout.isPublic ? .blue : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill((groupWorkout.isPublic ? Color.blue : Color.orange).opacity(0.1))
                )
                
                // Participants count with icon in colored box
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                    Text("\(groupWorkout.participantCount)/\(groupWorkout.maxParticipants)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.1))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // Text color for cancelled/ended workouts
    private var textColor: Color {
        switch groupWorkout.status {
        case .completed, .cancelled:
            return .gray
        default:
            return .primary
        }
    }
    
    private var secondaryTextColor: Color {
        switch groupWorkout.status {
        case .completed, .cancelled:
            return Color.gray.opacity(0.7)
        default:
            return .secondary
        }
    }
    
    // Time display logic
    private var statusTimeText: String {
        switch groupWorkout.status {
        case .active:
            return "Live"
        case .completed:
            return "Ended"
        case .cancelled:
            return "Cancelled"
        case .scheduled:
            let now = Date()
            if groupWorkout.scheduledStart <= now {
                return "Starting Soon"
            } else {
                let interval = groupWorkout.scheduledStart.timeIntervalSince(now)
                if interval < 60 {
                    return "Starting Soon"
                } else if interval < 3600 {
                    let minutes = Int(interval / 60)
                    return "Starts in \(minutes)m"
                } else if interval < 86400 {
                    let hours = Int(interval / 3600)
                    return "Starts in \(hours)h"
                } else {
                    let days = Int(interval / 86400)
                    return "Starts in \(days)d"
                }
            }
        }
    }
    
    private var statusTimeColor: Color {
        switch groupWorkout.status {
        case .active:
            return .green
        case .completed, .cancelled:
            return Color.gray.opacity(0.7)
        case .scheduled:
            let now = Date()
            if groupWorkout.scheduledStart.timeIntervalSince(now) < 60 {
                return .orange
            }
            return .blue
        }
    }
}