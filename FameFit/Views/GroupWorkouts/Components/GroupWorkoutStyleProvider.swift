//
//  GroupWorkoutStyleProvider.swift
//  FameFit
//
//  Centralized styling and configuration for group workout components
//

import SwiftUI

enum GroupWorkoutStyleProvider {
    // MARK: - Status Colors

    static func statusColor(for status: GroupWorkoutStatus) -> Color {
        switch status {
        case .scheduled:
            .blue
        case .active:
            .green
        case .completed:
            .gray
        case .cancelled:
            .red
        }
    }

    // MARK: - Background Colors

    static func backgroundColor(for status: GroupWorkoutStatus) -> Color {
        switch status {
        case .active:
            Color.green.opacity(0.05)
        case .scheduled:
            Color(.systemBackground)
        case .completed:
            Color(.systemGray6)
        case .cancelled:
            Color.red.opacity(0.05)
        }
    }

    // MARK: - Shadow Properties

    static func shadowColor(for status: GroupWorkoutStatus) -> Color {
        switch status {
        case .active:
            .green.opacity(0.2)
        case .scheduled:
            .black.opacity(0.1)
        default:
            .clear
        }
    }

    static func shadowRadius(for status: GroupWorkoutStatus) -> CGFloat {
        status == .active ? 8 : 4
    }

    static func shadowOffset(for status: GroupWorkoutStatus) -> CGFloat {
        status == .active ? 4 : 2
    }

    // MARK: - Border Properties

    static func borderColor(for status: GroupWorkoutStatus) -> Color {
        switch status {
        case .active:
            .green.opacity(0.3)
        default:
            .clear
        }
    }

    static func borderWidth(for status: GroupWorkoutStatus) -> CGFloat {
        status == .active ? 1 : 0
    }

    // MARK: - Time Display

    static func timeDisplayText(for status: GroupWorkoutStatus) -> String {
        switch status {
        case .scheduled:
            "Starts"
        case .active:
            "Live"
        case .completed:
            "Ended"
        case .cancelled:
            "Cancelled"
        }
    }

    static func timeDisplayColor(for status: GroupWorkoutStatus) -> Color {
        switch status {
        case .scheduled:
            .blue
        case .active:
            .green
        case .completed:
            .secondary
        case .cancelled:
            .red
        }
    }
}
