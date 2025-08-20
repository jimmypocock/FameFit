//
//  MockWorkoutKudosService.swift
//  FameFitTests
//
//  Mock implementation of WorkoutKudosProtocol for unit testing
//

import Combine
@testable import FameFit
import Foundation

/// Mock workout kudos service for testing
class MockWorkoutKudosService: WorkoutKudosProtocol {
    // Test control properties
    var toggleKudosCalled = false
    var removeKudosCalled = false
    var getKudosSummaryCalled = false
    var getUserKudosCalled = false
    var hasUserGivenKudosCalled = false
    var getKudosSummariesCalled = false

    // Test data
    var mockKudosSummaries: [String: WorkoutKudosSummary] = [:]
    var mockUserKudos: [WorkoutKudos] = []
    var mockHasUserGivenKudos: [String: Bool] = [:]
    var shouldFailToggleKudos = false
    var mockToggleResult: KudosActionResult = .added

    // Publisher for kudos updates
    private let kudosSubject = PassthroughSubject<KudosUpdate, Never>()
    var kudosUpdates: AnyPublisher<KudosUpdate, Never> {
        kudosSubject.eraseToAnyPublisher()
    }

    // Track calls
    var lastToggledWorkoutId: String?
    var lastToggledOwnerId: String?
    var lastRemovedWorkoutId: String?

    // Kudos actions
    func toggleKudos(for workoutID: String, ownerID: String) async throws -> KudosActionResult {
        toggleKudosCalled = true
        lastToggledWorkoutId = workoutID
        lastToggledOwnerId = ownerID

        if shouldFailToggleKudos {
            throw KudosError.rateLimited
        }

        // Simulate toggle behavior
        let hasKudos = mockHasUserGivenKudos[workoutID] ?? false
        let newAction: KudosActionResult = hasKudos ? .removed : .added
        mockHasUserGivenKudos[workoutID] = !hasKudos

        // Update summary
        if let summary = mockKudosSummaries[workoutID] {
            let newCount = hasKudos ? summary.totalCount - 1 : summary.totalCount + 1
            mockKudosSummaries[workoutID] = WorkoutKudosSummary(
                workoutID: workoutID,
                totalCount: newCount,
                hasUserKudos: !hasKudos,
                recentUsers: summary.recentUsers
            )
        } else {
            // Create new summary
            mockKudosSummaries[workoutID] = WorkoutKudosSummary(
                workoutID: workoutID,
                totalCount: 1,
                hasUserKudos: true,
                recentUsers: []
            )
        }

        // Emit update
        kudosSubject.send(KudosUpdate(
            workoutID: workoutID,
            action: newAction == .added ? .added : .removed,
            userID: "test-current-user",
            newCount: mockKudosSummaries[workoutID]?.totalCount ?? 0
        ))

        return newAction
    }

    func removeKudos(for workoutID: String) async throws {
        removeKudosCalled = true
        lastRemovedWorkoutId = workoutID

        mockHasUserGivenKudos[workoutID] = false
        if let summary = mockKudosSummaries[workoutID] {
            let newCount = max(0, summary.totalCount - 1)
            mockKudosSummaries[workoutID] = WorkoutKudosSummary(
                workoutID: workoutID,
                totalCount: newCount,
                hasUserKudos: false,
                recentUsers: summary.recentUsers
            )
        }
    }

    // Fetching kudos
    func getKudosSummary(for workoutID: String) async throws -> WorkoutKudosSummary {
        getKudosSummaryCalled = true

        if let summary = mockKudosSummaries[workoutID] {
            return summary
        }

        // Return default empty summary
        return WorkoutKudosSummary(
            workoutID: workoutID,
            totalCount: 0,
            hasUserKudos: false,
            recentUsers: []
        )
    }

    func getUserKudos(for _: String, limit: Int) async throws -> [WorkoutKudos] {
        getUserKudosCalled = true
        return Array(mockUserKudos.prefix(limit))
    }

    func hasUserGivenKudos(workoutID: String, userID _: String) async throws -> Bool {
        hasUserGivenKudosCalled = true
        return mockHasUserGivenKudos[workoutID] ?? false
    }

    // Batch operations
    func getKudosSummaries(for workoutIDs: [String]) async throws -> [String: WorkoutKudosSummary] {
        getKudosSummariesCalled = true

        var summaries: [String: WorkoutKudosSummary] = [:]
        for workoutID in workoutIDs {
            if let summary = mockKudosSummaries[workoutID] {
                summaries[workoutID] = summary
            } else {
                summaries[workoutID] = WorkoutKudosSummary(
                    workoutID: workoutID,
                    totalCount: 0,
                    hasUserKudos: false,
                    recentUsers: []
                )
            }
        }
        return summaries
    }

    // Test helper methods
    func reset() {
        toggleKudosCalled = false
        removeKudosCalled = false
        getKudosSummaryCalled = false
        getUserKudosCalled = false
        hasUserGivenKudosCalled = false
        getKudosSummariesCalled = false

        mockKudosSummaries.removeAll()
        mockUserKudos.removeAll()
        mockHasUserGivenKudos.removeAll()
        shouldFailToggleKudos = false
        mockToggleResult = .added

        lastToggledWorkoutId = nil
        lastToggledOwnerId = nil
        lastRemovedWorkoutId = nil
    }

    func simulateKudos(
        for workoutID: String,
        count: Int,
        hasUserKudos: Bool,
        recentUsers: [WorkoutKudosSummary.KudosUser] = []
    ) {
        mockKudosSummaries[workoutID] = WorkoutKudosSummary(
            workoutID: workoutID,
            totalCount: count,
            hasUserKudos: hasUserKudos,
            recentUsers: recentUsers
        )
        mockHasUserGivenKudos[workoutID] = hasUserKudos
    }

    func emitKudosUpdate(_ update: KudosUpdate) {
        kudosSubject.send(update)
    }
}
