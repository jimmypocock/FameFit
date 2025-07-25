//
//  MockGroupWorkoutService.swift
//  FameFitTests
//
//  Mock implementation of GroupWorkoutServicing for testing
//

import Combine
@testable import FameFit
import Foundation
import HealthKit

final class MockGroupWorkoutService: GroupWorkoutServicing {
    // MARK: - Test Control Properties

    var shouldFail = false
    var errorToThrow: Error?

    // MARK: - Test Data

    var mockWorkouts: [GroupWorkout] = []
    var createdWorkouts: [GroupWorkout] = []
    var joinedWorkouts: [String] = []
    var leftWorkouts: [String] = []

    // Dependencies for testing
    weak var notificationManager: MockNotificationManager?

    // MARK: - Method Call Tracking

    var createGroupWorkoutCalled = false
    var updateGroupWorkoutCalled = false
    var cancelGroupWorkoutCalled = false
    var startGroupWorkoutCalled = false
    var completeGroupWorkoutCalled = false
    var joinGroupWorkoutCalled = false
    var joinWithCodeCalled = false
    var leaveGroupWorkoutCalled = false
    var updateParticipantDataCalled = false
    var fetchUpcomingWorkoutsCalled = false
    var fetchActiveWorkoutsCalled = false
    var fetchMyWorkoutsCalled = false
    var fetchWorkoutCalled = false
    var searchWorkoutsCalled = false

    // MARK: - Publishers

    private let activeWorkoutUpdatesSubject = PassthroughSubject<GroupWorkoutUpdate, Never>()
    var activeWorkoutUpdates: AnyPublisher<GroupWorkoutUpdate, Never> {
        activeWorkoutUpdatesSubject.eraseToAnyPublisher()
    }

    // MARK: - Host Operations

    func createGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout {
        createGroupWorkoutCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.saveFailed
        }

        // Add default participant if none exist
        var newWorkout = workout
        if newWorkout.participants.isEmpty {
            let hostParticipant = GroupWorkoutParticipant(
                userId: workout.hostId,
                displayName: "Test User",
                profileImageURL: nil
            )
            newWorkout.participants.append(hostParticipant)
        }

        createdWorkouts.append(newWorkout)
        mockWorkouts.append(newWorkout)

        return newWorkout
    }

    func updateGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout {
        updateGroupWorkoutCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.updateFailed
        }

        // Update in mock storage
        if let index = mockWorkouts.firstIndex(where: { $0.id == workout.id }) {
            var updatedWorkout = workout
            updatedWorkout.updatedAt = Date()
            mockWorkouts[index] = updatedWorkout
            return updatedWorkout
        }

        throw GroupWorkoutError.workoutNotFound
    }

    func cancelGroupWorkout(workoutId: String) async throws {
        cancelGroupWorkoutCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.updateFailed
        }

        if let index = mockWorkouts.firstIndex(where: { $0.id == workoutId }) {
            mockWorkouts[index].status = .cancelled
            mockWorkouts[index].updatedAt = Date()
        } else {
            throw GroupWorkoutError.workoutNotFound
        }
    }

    func startGroupWorkout(workoutId: String) async throws -> GroupWorkout {
        startGroupWorkoutCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.updateFailed
        }

        guard let index = mockWorkouts.firstIndex(where: { $0.id == workoutId }) else {
            throw GroupWorkoutError.workoutNotFound
        }

        let workout = mockWorkouts[index]

        // Check if user is a participant
        guard workout.participants.contains(where: { $0.userId == "test-user-123" }) else {
            throw GroupWorkoutError.notParticipant
        }

        // Update workout status
        mockWorkouts[index].status = .active
        mockWorkouts[index].updatedAt = Date()

        // Update participant status and data
        if let participantIndex = mockWorkouts[index].participants.firstIndex(where: { $0.userId == "test-user-123" }) {
            mockWorkouts[index].participants[participantIndex].status = .active
            mockWorkouts[index].participants[participantIndex].workoutData = GroupWorkoutData(
                startTime: Date(),
                totalEnergyBurned: 0,
                totalDistance: 0,
                lastUpdated: Date()
            )
        }

        // Simulate notification sending
        if let notificationManager {
            notificationManager.scheduleNotificationCalled = true
        }

        return mockWorkouts[index]
    }

    func completeGroupWorkout(workoutId: String) async throws -> GroupWorkout {
        completeGroupWorkoutCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.updateFailed
        }

        guard let index = mockWorkouts.firstIndex(where: { $0.id == workoutId }) else {
            throw GroupWorkoutError.workoutNotFound
        }

        // Update workout status
        mockWorkouts[index].status = .completed
        mockWorkouts[index].updatedAt = Date()

        // Update participant status and end time
        if let participantIndex = mockWorkouts[index].participants.firstIndex(where: { $0.userId == "test-user-123" }) {
            mockWorkouts[index].participants[participantIndex].status = .completed
            if var workoutData = mockWorkouts[index].participants[participantIndex].workoutData {
                workoutData.endTime = Date()
                mockWorkouts[index].participants[participantIndex].workoutData = workoutData
            }
        }

        return mockWorkouts[index]
    }

    // MARK: - Participant Operations

    func joinGroupWorkout(workoutId: String) async throws -> GroupWorkout {
        joinGroupWorkoutCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.cannotJoin
        }

        guard let index = mockWorkouts.firstIndex(where: { $0.id == workoutId }) else {
            throw GroupWorkoutError.workoutNotFound
        }

        let workout = mockWorkouts[index]

        // Check if workout is cancelled
        if workout.status == .cancelled {
            throw GroupWorkoutError.cannotJoin
        }

        // Check if workout is full
        if workout.participants.count >= workout.maxParticipants {
            throw GroupWorkoutError.workoutFull
        }

        let participant = GroupWorkoutParticipant(
            userId: "test-user-123",
            displayName: "Test User",
            profileImageURL: nil
        )

        let alreadyJoined = mockWorkouts[index].participants.contains(where: { $0.userId == participant.userId })

        if !alreadyJoined {
            mockWorkouts[index].participants.append(participant)
            joinedWorkouts.append(workoutId)

            // Simulate notification to host
            if let notificationManager {
                notificationManager.scheduleNotificationCalled = true
                notificationManager.lastScheduledUserId = workout.hostId
            }
        }

        return mockWorkouts[index]
    }

    func joinWithCode(_ code: String) async throws -> GroupWorkout {
        joinWithCodeCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.invalidJoinCode
        }

        if let workout = mockWorkouts.first(where: { $0.joinCode == code }) {
            return try await joinGroupWorkout(workoutId: workout.id)
        }

        throw GroupWorkoutError.invalidJoinCode
    }

    func leaveGroupWorkout(workoutId: String) async throws {
        leaveGroupWorkoutCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.updateFailed
        }

        guard let index = mockWorkouts.firstIndex(where: { $0.id == workoutId }) else {
            throw GroupWorkoutError.workoutNotFound
        }

        let workout = mockWorkouts[index]

        // Check if user is the host
        if workout.hostId == "test-user-123" {
            throw GroupWorkoutError.hostCannotLeave
        }

        mockWorkouts[index].participants.removeAll(where: { $0.userId == "test-user-123" })
        leftWorkouts.append(workoutId)
    }

    func updateParticipantData(workoutId: String, data: GroupWorkoutData) async throws {
        updateParticipantDataCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.updateFailed
        }

        // Send update via publisher
        let update = GroupWorkoutUpdate(
            workoutId: workoutId,
            participantId: "test-user-123",
            updateType: .progress,
            data: data,
            timestamp: Date()
        )
        activeWorkoutUpdatesSubject.send(update)
    }

    // MARK: - Fetching

    func fetchUpcomingWorkouts(limit: Int) async throws -> [GroupWorkout] {
        fetchUpcomingWorkoutsCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.fetchFailed
        }

        // Filter for public, scheduled workouts only
        let upcoming = mockWorkouts.filter { $0.isUpcoming && $0.isPublic && $0.status == .scheduled }
        return Array(upcoming.prefix(limit))
    }

    func fetchActiveWorkouts() async throws -> [GroupWorkout] {
        fetchActiveWorkoutsCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.fetchFailed
        }

        return mockWorkouts.filter { $0.status == .active }
    }

    func fetchMyWorkouts(userId: String) async throws -> [GroupWorkout] {
        fetchMyWorkoutsCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.fetchFailed
        }

        return mockWorkouts.filter { workout in
            workout.hostId == userId || workout.participants.contains(where: { $0.userId == userId })
        }
    }

    func fetchWorkout(workoutId: String) async throws -> GroupWorkout {
        fetchWorkoutCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.fetchFailed
        }

        guard let workout = mockWorkouts.first(where: { $0.id == workoutId }) else {
            throw GroupWorkoutError.workoutNotFound
        }

        return workout
    }

    func searchWorkouts(query: String, workoutType: HKWorkoutActivityType?) async throws -> [GroupWorkout] {
        searchWorkoutsCalled = true

        if let error = errorToThrow {
            throw error
        }

        if shouldFail {
            throw GroupWorkoutError.fetchFailed
        }

        return mockWorkouts.filter { workout in
            // If query is empty and workoutType is specified, match by type only
            if query.isEmpty && workoutType != nil {
                return workout.workoutType == workoutType && workout.isPublic && workout.status == .scheduled
            }

            // Otherwise match by query in name, description, or tags
            let matchesQuery = query.isEmpty ||
                workout.name.localizedCaseInsensitiveContains(query) ||
                workout.description.localizedCaseInsensitiveContains(query) ||
                workout.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            let matchesType = workoutType == nil || workout.workoutType == workoutType
            return matchesQuery && matchesType && workout.isPublic && workout.status == .scheduled
        }
    }

    // MARK: - Helper Methods

    func reset() {
        shouldFail = false
        errorToThrow = nil
        mockWorkouts.removeAll()
        createdWorkouts.removeAll()
        joinedWorkouts.removeAll()
        leftWorkouts.removeAll()

        createGroupWorkoutCalled = false
        updateGroupWorkoutCalled = false
        cancelGroupWorkoutCalled = false
        startGroupWorkoutCalled = false
        completeGroupWorkoutCalled = false
        joinGroupWorkoutCalled = false
        joinWithCodeCalled = false
        leaveGroupWorkoutCalled = false
        updateParticipantDataCalled = false
        fetchUpcomingWorkoutsCalled = false
        fetchActiveWorkoutsCalled = false
        fetchMyWorkoutsCalled = false
        fetchWorkoutCalled = false
        searchWorkoutsCalled = false
    }

    func sendUpdate(_ update: GroupWorkoutUpdate) {
        activeWorkoutUpdatesSubject.send(update)
    }
}
