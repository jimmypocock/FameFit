//
//  ChallengeDetailView.swift
//  FameFit
//
//  Detailed view for a single workout challenge
//

import SwiftUI

struct ChallengeDetailView: View {
    let challenge: WorkoutChallenge
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    @State private var isUpdatingProgress = false
    @State private var showingUpdateProgress = false
    @State private var error: String?

    private var currentUserId: String? {
        container.cloudKitManager.currentUserID
    }

    private var myParticipant: ChallengeParticipant? {
        challenge.participants.first { $0.id == currentUserId }
    }

    private var sortedParticipants: [ChallengeParticipant] {
        challenge.participants.sorted { $0.progress > $1.progress }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView

                    // Progress Overview
                    progressOverview

                    // Leaderboard
                    leaderboardView

                    // Challenge Details
                    detailsView

                    // Actions
                    if challenge.status == .active {
                        actionButtons
                    }
                }
                .padding()
            }
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingUpdateProgress) {
                UpdateProgressView(
                    challenge: challenge,
                    currentProgress: myParticipant?.progress ?? 0
                ) { newProgress in
                    updateProgress(newProgress)
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 12) {
            // Icon and name
            Text(challenge.type.icon)
                .font(.system(size: 60))

            Text(challenge.name)
                .font(.title2)
                .fontWeight(.bold)

            // Status badge
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)

                Text(statusText)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.1))
            .cornerRadius(20)
        }
    }

    private var statusIcon: String {
        switch challenge.status {
        case .pending:
            "clock"
        case .active:
            "bolt.fill"
        case .completed:
            "checkmark.circle.fill"
        case .cancelled, .declined:
            "xmark.circle.fill"
        case .expired:
            "exclamationmark.triangle.fill"
        case .accepted:
            "checkmark"
        }
    }

    private var statusColor: Color {
        switch challenge.status {
        case .pending, .accepted:
            .orange
        case .active:
            .green
        case .completed:
            .blue
        case .cancelled, .declined, .expired:
            .red
        }
    }

    private var statusText: String {
        switch challenge.status {
        case .pending:
            "Pending"
        case .accepted:
            "Accepted"
        case .active:
            if challenge.isExpired {
                "Expired"
            } else {
                "\(challenge.daysRemaining) days remaining"
            }
        case .completed:
            "Completed"
        case .cancelled:
            "Cancelled"
        case .declined:
            "Declined"
        case .expired:
            "Expired"
        }
    }

    // MARK: - Progress Overview

    private var progressOverview: some View {
        VStack(spacing: 16) {
            // Overall progress
            VStack(spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.headline)

                    Spacer()

                    Text("\(Int(challenge.progressPercentage))%")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(
                                width: geometry.size.width * (challenge.progressPercentage / 100),
                                height: 12
                            )
                            .animation(.easeInOut(duration: 0.5), value: challenge.progressPercentage)
                    }
                }
                .frame(height: 12)
            }

            // My progress (if participating)
            if let myParticipant {
                VStack(spacing: 8) {
                    HStack {
                        Text("My Progress")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(myParticipant.progress)) / \(Int(challenge.targetValue)) \(challenge.type.unit)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                                .frame(
                                    width: geometry.size.width * min(
                                        1.0,
                                        myParticipant.progress / challenge.targetValue
                                    ),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Leaderboard View

    private var leaderboardView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leaderboard")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(Array(sortedParticipants.enumerated()), id: \.element.id) { index, participant in
                    HStack(spacing: 12) {
                        // Position
                        ZStack {
                            Circle()
                                .fill(positionColor(for: index))
                                .frame(width: 32, height: 32)

                            Text("\(index + 1)")
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }

                        // Name
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(participant.displayName)
                                    .font(.body)
                                    .fontWeight(participant.id == currentUserId ? .medium : .regular)

                                if participant.id == challenge.winnerId {
                                    Image(systemName: "trophy.fill")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                            }

                            if participant.lastUpdated > Date().addingTimeInterval(-3600) {
                                Text("Updated recently")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }

                        Spacer()

                        // Progress
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(participant.progress)) \(challenge.type.unit)")
                                .font(.callout)
                                .fontWeight(.medium)

                            Text("\(Int((participant.progress / challenge.targetValue) * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(participant.id == currentUserId ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func positionColor(for index: Int) -> Color {
        switch index {
        case 0:
            .yellow
        case 1:
            .gray
        case 2:
            .orange
        default:
            .accentColor
        }
    }

    // MARK: - Details View

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 12) {
                DetailRow(label: "Target", value: "\(Int(challenge.targetValue)) \(challenge.type.unit)")
                DetailRow(
                    label: "Duration",
                    value: "\(challenge.startDate.formatted(date: .abbreviated, time: .omitted)) - \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))"
                )

                if challenge.xpStake > 0 {
                    DetailRow(label: "XP Stake", value: "\(challenge.xpStake) XP per person")
                    if challenge.winnerTakesAll {
                        DetailRow(
                            label: "Prize",
                            value: "Winner takes all (\(challenge.xpStake * challenge.participants.count) XP)"
                        )
                    }
                }

                if !challenge.description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(challenge.description)
                            .font(.callout)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if myParticipant != nil {
                Button(action: {
                    showingUpdateProgress = true
                }) {
                    Label("Update Progress", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdatingProgress)
            }

            if challenge.creatorId == currentUserId, challenge.status == .active {
                Button(action: {
                    cancelChallenge()
                }) {
                    Label("Cancel Challenge", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
    }

    // MARK: - Actions

    private func updateProgress(_ newProgress: Double) {
        isUpdatingProgress = true
        error = nil

        Task {
            do {
                try await container.workoutChallengesService.updateProgress(
                    challengeId: challenge.id,
                    progress: newProgress,
                    workoutId: nil
                )

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isUpdatingProgress = false
                }
            }
        }
    }

    private func cancelChallenge() {
        Task {
            do {
                try await container.workoutChallengesService.cancelChallenge(challengeId: challenge.id)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Update Progress View

struct UpdateProgressView: View {
    let challenge: WorkoutChallenge
    let currentProgress: Double
    let onUpdate: (Double) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var newProgress: String

    init(challenge: WorkoutChallenge, currentProgress: Double, onUpdate: @escaping (Double) -> Void) {
        self.challenge = challenge
        self.currentProgress = currentProgress
        self.onUpdate = onUpdate
        _newProgress = State(initialValue: String(format: "%.0f", currentProgress))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Update your progress for")
                    .font(.headline)

                Text(challenge.name)
                    .font(.title3)
                    .fontWeight(.medium)

                HStack {
                    TextField("Progress", text: $newProgress)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    Text(challenge.type.unit)
                        .foregroundColor(.secondary)
                }
                .font(.title)

                Text("Current: \(Int(currentProgress)) \(challenge.type.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        if let progress = Double(newProgress) {
                            onUpdate(progress)
                            dismiss()
                        }
                    }
                    .fontWeight(.medium)
                    .disabled(newProgress.isEmpty || Double(newProgress) == nil)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChallengeDetailView(
        challenge: WorkoutChallenge(
            id: "preview-challenge",
            creatorId: "preview-creator",
            participants: [
                ChallengeParticipant(
                    id: "preview-creator",
                    displayName: "Creator",
                    profileImageURL: nil,
                    progress: 25
                ),
                ChallengeParticipant(
                    id: "preview-participant",
                    displayName: "Participant",
                    profileImageURL: nil,
                    progress: 30
                ),
            ],
            type: .distance,
            targetValue: 50,
            workoutType: nil,
            name: "Distance Challenge",
            description: "Reach 50 km",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 24 * 3600),
            createdAt: Date(),
            status: .active,
            winnerId: nil,
            xpStake: 100,
            winnerTakesAll: false,
            isPublic: true
        )
    )
    .environment(\.dependencyContainer, DependencyContainer())
}
