//
//  ChallengesView.swift
//  FameFit
//
//  Main view for displaying and managing workout challenges
//

import SwiftUI

struct ChallengesView: View {
    @Environment(\.dependencyContainer) var container
    @StateObject private var viewModel = ChallengesViewModel()

    @State private var selectedTab = 0
    @State private var showingCreateChallenge = false
    @State private var selectedChallenge: WorkoutChallenge?
    @State private var showingChallengeDetails = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Challenge Type", selection: $selectedTab) {
                Text("Active").tag(0)
                Text("Pending").tag(1)
                Text("Completed").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            // Content based on selected tab
            Group {
                switch selectedTab {
                case 0:
                    activeChallengesView
                case 1:
                    pendingChallengesView
                case 2:
                    completedChallengesView
                default:
                    EmptyView()
                }
            }
        }
        .navigationTitle("Challenges")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingCreateChallenge = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateChallenge) {
            CreateChallengeView()
                .environment(\.dependencyContainer, container)
        }
        .sheet(isPresented: $showingChallengeDetails) {
            if let challenge = selectedChallenge {
                ChallengeDetailView(challenge: challenge)
                    .environment(\.dependencyContainer, container)
            }
        }
        .task {
            viewModel.configure(
                challengesService: container.workoutChallengesService,
                userProfileService: container.userProfileService,
                currentUserId: container.cloudKitManager.currentUserID ?? ""
            )
            await viewModel.loadChallenges()
        }
    }

    // MARK: - Active Challenges View

    private var activeChallengesView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading challenges...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.activeChallenges.isEmpty {
                emptyStateView(
                    title: "No Active Challenges",
                    message: "Create or join a challenge to get started!",
                    action: {
                        showingCreateChallenge = true
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.activeChallenges) { challenge in
                            ChallengeCard(challenge: challenge, currentUserId: viewModel.currentUserId) {
                                selectedChallenge = challenge
                                showingChallengeDetails = true
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }

    // MARK: - Pending Challenges View

    private var pendingChallengesView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading challenges...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.pendingChallenges.isEmpty {
                emptyStateView(
                    title: "No Pending Invites",
                    message: "You don't have any pending challenge invitations",
                    action: nil
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.pendingChallenges) { challenge in
                            PendingChallengeCard(
                                challenge: challenge,
                                onAccept: {
                                    Task {
                                        await viewModel.acceptChallenge(challenge)
                                    }
                                },
                                onDecline: {
                                    Task {
                                        await viewModel.declineChallenge(challenge)
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }

    // MARK: - Completed Challenges View

    private var completedChallengesView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading challenges...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.completedChallenges.isEmpty {
                emptyStateView(
                    title: "No Completed Challenges",
                    message: "Complete your first challenge to see it here!",
                    action: nil
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.completedChallenges) { challenge in
                            CompletedChallengeCard(
                                challenge: challenge,
                                currentUserId: viewModel.currentUserId
                            ) {
                                selectedChallenge = challenge
                                showingChallengeDetails = true
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }

    // MARK: - Empty State View

    private func emptyStateView(title: String, message: String, action: (() -> Void)?) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let action {
                Button("Create Challenge", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Challenge Card

struct ChallengeCard: View {
    let challenge: WorkoutChallenge
    let currentUserId: String
    let onTap: () -> Void

    private var myProgress: ChallengeParticipant? {
        challenge.participants.first { $0.id == currentUserId }
    }

    private var progressColor: Color {
        if challenge.progressPercentage >= 80 {
            .green
        } else if challenge.progressPercentage >= 50 {
            .yellow
        } else {
            .orange
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text(challenge.type.icon)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(challenge.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("\(challenge.daysRemaining) days remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if let leader = challenge.leadingParticipant {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Leading")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(leader.username)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(leader.id == currentUserId ? .green : .primary)
                        }
                    }
                }

                // Progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("My Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        if let myProgress {
                            Text("\(Int(myProgress.progress)) / \(Int(challenge.targetValue)) \(challenge.type.unit)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)

                            if let myProgress {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(progressColor)
                                    .frame(
                                        width: geometry.size.width * min(
                                            1.0,
                                            myProgress.progress / challenge.targetValue
                                        ),
                                        height: 8
                                    )
                                    .animation(.easeInOut(duration: 0.3), value: myProgress.progress)
                            }
                        }
                    }
                    .frame(height: 8)
                }

                // Participants preview
                HStack {
                    ForEach(challenge.participants.prefix(3)) { participant in
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 24, height: 24)

                            Text(String(participant.username.prefix(1)))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }

                    if challenge.participants.count > 3 {
                        Text("+\(challenge.participants.count - 3)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if challenge.xpStake > 0 {
                        Label("\(challenge.xpStake) XP", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pending Challenge Card

struct PendingChallengeCard: View {
    let challenge: WorkoutChallenge
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(challenge.type.icon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.name)
                        .font(.headline)

                    Text("From \(challenge.participants.first?.username ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Details
            Text(challenge.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label("\(Int(challenge.targetValue)) \(challenge.type.unit)", systemImage: "target")
                    .font(.caption)

                Spacer()

                Label("\(challenge.daysRemaining) days", systemImage: "calendar")
                    .font(.caption)

                if challenge.xpStake > 0 {
                    Label("\(challenge.xpStake) XP", systemImage: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onDecline) {
                    Text("Decline")
                        .font(.callout)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onAccept) {
                    Text("Accept")
                        .font(.callout)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Completed Challenge Card

struct CompletedChallengeCard: View {
    let challenge: WorkoutChallenge
    let currentUserId: String
    let onTap: () -> Void

    private var didWin: Bool {
        challenge.winnerId == currentUserId
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(challenge.type.icon)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(challenge.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Completed \(challenge.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if didWin {
                        VStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                                .font(.title2)
                            Text("Winner!")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                        }
                    }
                }

                if let winner = challenge.participants.first(where: { $0.id == challenge.winnerId }) {
                    HStack {
                        Text("Winner: \(winner.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(winner.progress)) \(challenge.type.unit)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ChallengesView()
            .environment(\.dependencyContainer, DependencyContainer())
    }
}
