//
//  ChallengesViewModel.swift
//  FameFit
//
//  View model for managing workout challenges
//

import Combine
import Foundation

@MainActor
final class ChallengesViewModel: ObservableObject {
    @Published var activeChallenges: [WorkoutChallenge] = []
    @Published var pendingChallenges: [WorkoutChallenge] = []
    @Published var completedChallenges: [WorkoutChallenge] = []
    @Published var isLoading = false
    @Published var error: String?

    private var challengesService: WorkoutChallengesServicing?
    private var userProfileService: UserProfileServicing?
    private(set) var currentUserID = ""
    private var cancellables = Set<AnyCancellable>()

    func configure(
        challengesService: WorkoutChallengesServicing,
        userProfileService: UserProfileServicing,
        currentUserID: String
    ) {
        self.challengesService = challengesService
        self.userProfileService = userProfileService
        self.currentUserID = currentUserID

        // Set up real-time updates
        startRealTimeUpdates()
    }

    func loadChallenges() async {
        isLoading = true
        error = nil

        do {
            guard let service = challengesService else { return }

            // Load all challenge types in parallel
            async let active = service.fetchActiveChallenge(for: currentUserID)
            async let pending = service.fetchPendingChallenge(for: currentUserID)
            async let completed = service.fetchCompletedChallenge(for: currentUserID)

            // Wait for all to complete
            let (activeResults, pendingResults, completedResults) = try await (active, pending, completed)

            // Update published properties
            activeChallenges = activeResults
            pendingChallenges = pendingResults
            completedChallenges = completedResults
        } catch {
            self.error = "Failed to load challenges: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func acceptChallenge(_ challenge: WorkoutChallenge) async {
        guard let service = challengesService else { return }

        do {
            let acceptedChallenge = try await service.acceptChallenge(workoutChallengeID: challenge.id)

            // Move from pending to active
            pendingChallenges.removeAll { $0.id == challenge.id }
            activeChallenges.append(acceptedChallenge)
        } catch {
            self.error = "Failed to accept challenge: \(error.localizedDescription)"
        }
    }

    func declineChallenge(_ challenge: WorkoutChallenge) async {
        guard let service = challengesService else { return }

        do {
            try await service.declineChallenge(workoutChallengeID: challenge.id)

            // Remove from pending
            pendingChallenges.removeAll { $0.id == challenge.id }
        } catch {
            self.error = "Failed to decline challenge: \(error.localizedDescription)"
        }
    }

    func updateProgress(for challenge: WorkoutChallenge, progress: Double, workoutID: String? = nil) async {
        guard let service = challengesService else { return }

        do {
            try await service.updateProgress(
                workoutChallengeID: challenge.id,
                progress: progress,
                workoutID: workoutID
            )

            // Reload to get updated data
            await loadChallenges()
        } catch {
            self.error = "Failed to update progress: \(error.localizedDescription)"
        }
    }

    // MARK: - Real-time Updates

    private func startRealTimeUpdates() {
        // Set up a timer to periodically check for updates
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshActiveChallenges()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshActiveChallenges() async {
        guard !isLoading,
              let service = challengesService,
              !currentUserID.isEmpty
        else {
            return
        }

        do {
            let updatedChallenges = try await service.fetchActiveChallenge(for: currentUserID)

            // Check for completed challenges
            for challenge in activeChallenges {
                if let updated = updatedChallenges.first(where: { $0.id == challenge.id }),
                   updated.status == .completed, challenge.status != .completed {
                    // Move to completed
                    activeChallenges.removeAll { $0.id == challenge.id }
                    completedChallenges.insert(updated, at: 0)
                }
            }

            // Update active challenges
            activeChallenges = updatedChallenges.filter { $0.status == .active }
        } catch {
            // Silently fail for background updates
            print("Failed to refresh challenges: \(error)")
        }
    }
}
