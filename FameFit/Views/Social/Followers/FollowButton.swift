//
//  FollowButton.swift
//  FameFit
//
//  Reusable follow button component with different states
//

import SwiftUI

struct FollowButton: View {
    let relationshipStatus: RelationshipStatus
    let isProcessing: Bool
    let onFollowAction: () async -> Void

    var body: some View {
        Button(action: {
            Task {
                await onFollowAction()
            }
        }) {
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 90, height: 32)
            } else {
                Text(followButtonTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(followButtonForegroundColor)
                    .frame(width: 90, height: 32)
                    .background(followButtonBackground)
                    .cornerRadius(16)
            }
        }
        .disabled(isProcessing || relationshipStatus == .blocked)
    }

    private var followButtonTitle: String {
        switch relationshipStatus {
        case .following, .mutualFollow:
            "Following"
        case .blocked:
            "Blocked"
        case .pending:
            "Requested"
        default:
            "Follow"
        }
    }

    private var followButtonForegroundColor: Color {
        switch relationshipStatus {
        case .following, .mutualFollow:
            .primary
        case .blocked:
            .red
        default:
            .white
        }
    }

    private var followButtonBackground: Color {
        switch relationshipStatus {
        case .following, .mutualFollow:
            Color(.systemGray5)
        case .blocked:
            Color.red.opacity(0.1)
        case .pending:
            Color.orange.opacity(0.2)
        default:
            .blue
        }
    }
}