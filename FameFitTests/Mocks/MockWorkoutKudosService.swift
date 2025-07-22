//
//  MockWorkoutKudosService.swift
//  FameFitTests
//
//  Mock implementation of WorkoutKudosServicing for unit testing
//

import Foundation
import Combine
@testable import FameFit

/// Mock workout kudos service for testing
class MockWorkoutKudosService: WorkoutKudosServicing {
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
    func toggleKudos(for workoutId: String, ownerId: String) async throws -> KudosActionResult {
        toggleKudosCalled = true
        lastToggledWorkoutId = workoutId
        lastToggledOwnerId = ownerId
        
        if shouldFailToggleKudos {
            throw KudosError.rateLimited
        }
        
        // Simulate toggle behavior
        let hasKudos = mockHasUserGivenKudos[workoutId] ?? false
        let newAction: KudosActionResult = hasKudos ? .removed : .added
        mockHasUserGivenKudos[workoutId] = !hasKudos
        
        // Update summary
        if let summary = mockKudosSummaries[workoutId] {
            let newCount = hasKudos ? summary.totalCount - 1 : summary.totalCount + 1
            mockKudosSummaries[workoutId] = WorkoutKudosSummary(
                workoutId: workoutId,
                totalCount: newCount,
                hasUserKudos: !hasKudos,
                recentUsers: summary.recentUsers
            )
        } else {
            // Create new summary
            mockKudosSummaries[workoutId] = WorkoutKudosSummary(
                workoutId: workoutId,
                totalCount: 1,
                hasUserKudos: true,
                recentUsers: []
            )
        }
        
        // Emit update
        kudosSubject.send(KudosUpdate(
            workoutId: workoutId,
            action: newAction == .added ? .added : .removed,
            userID: "test-current-user",
            newCount: mockKudosSummaries[workoutId]?.totalCount ?? 0
        ))
        
        return newAction
    }
    
    func removeKudos(for workoutId: String) async throws {
        removeKudosCalled = true
        lastRemovedWorkoutId = workoutId
        
        mockHasUserGivenKudos[workoutId] = false
        if let summary = mockKudosSummaries[workoutId] {
            let newCount = max(0, summary.totalCount - 1)
            mockKudosSummaries[workoutId] = WorkoutKudosSummary(
                workoutId: workoutId,
                totalCount: newCount,
                hasUserKudos: false,
                recentUsers: summary.recentUsers
            )
        }
    }
    
    // Fetching kudos
    func getKudosSummary(for workoutId: String) async throws -> WorkoutKudosSummary {
        getKudosSummaryCalled = true
        
        if let summary = mockKudosSummaries[workoutId] {
            return summary
        }
        
        // Return default empty summary
        return WorkoutKudosSummary(
            workoutId: workoutId,
            totalCount: 0,
            hasUserKudos: false,
            recentUsers: []
        )
    }
    
    func getUserKudos(for userId: String, limit: Int) async throws -> [WorkoutKudos] {
        getUserKudosCalled = true
        return Array(mockUserKudos.prefix(limit))
    }
    
    func hasUserGivenKudos(workoutId: String, userId: String) async throws -> Bool {
        hasUserGivenKudosCalled = true
        return mockHasUserGivenKudos[workoutId] ?? false
    }
    
    // Batch operations
    func getKudosSummaries(for workoutIds: [String]) async throws -> [String: WorkoutKudosSummary] {
        getKudosSummariesCalled = true
        
        var summaries: [String: WorkoutKudosSummary] = [:]
        for workoutId in workoutIds {
            if let summary = mockKudosSummaries[workoutId] {
                summaries[workoutId] = summary
            } else {
                summaries[workoutId] = WorkoutKudosSummary(
                    workoutId: workoutId,
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
    
    func simulateKudos(for workoutId: String, count: Int, hasUserKudos: Bool, recentUsers: [WorkoutKudosSummary.KudosUser] = []) {
        mockKudosSummaries[workoutId] = WorkoutKudosSummary(
            workoutId: workoutId,
            totalCount: count,
            hasUserKudos: hasUserKudos,
            recentUsers: recentUsers
        )
        mockHasUserGivenKudos[workoutId] = hasUserKudos
    }
    
    func emitKudosUpdate(_ update: KudosUpdate) {
        kudosSubject.send(update)
    }
}