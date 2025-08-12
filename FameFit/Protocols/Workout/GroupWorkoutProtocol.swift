//
//  GroupWorkoutProtocol.swift
//  FameFit
//
//  Consolidated protocol for all group workout operations
//

import Combine
import Foundation
import HealthKit

/// Protocol for managing all group workout operations
/// Provides thread-safe, modern async/await API for group workout functionality
protocol GroupWorkoutProtocol: AnyObject, Sendable {
    // MARK: - Workout Management
    
    func createGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout
    func updateGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout
    func deleteGroupWorkout(_ workoutID: String) async throws
    func cancelGroupWorkout(_ workoutID: String) async throws
    func startGroupWorkout(_ workoutID: String) async throws -> GroupWorkout
    func completeGroupWorkout(_ workoutID: String) async throws -> GroupWorkout
    
    // MARK: - Participant Management
    
    func joinGroupWorkout(_ workoutID: String) async throws
    func joinWithCode(_ code: String) async throws -> GroupWorkout
    func leaveGroupWorkout(_ workoutID: String) async throws
    func updateParticipantStatus(_ workoutID: String, status: ParticipantStatus) async throws
    func updateParticipantData(_ workoutID: String, data: GroupWorkoutData) async throws
    func getParticipants(_ workoutID: String) async throws -> [GroupWorkoutParticipant]
    
    // MARK: - Discovery
    
    func fetchUpcomingWorkouts(limit: Int) async throws -> [GroupWorkout]
    func fetchActiveWorkouts() async throws -> [GroupWorkout]
    func fetchMyWorkouts() async throws -> [GroupWorkout]
    func fetchWorkout(_ workoutID: String) async throws -> GroupWorkout
    func fetchPublicWorkouts(tags: [String]?, limit: Int) async throws -> [GroupWorkout]
    func searchWorkouts(query: String, filters: WorkoutFilters?) async throws -> [GroupWorkout]
    
    // MARK: - Invites
    
    func inviteUser(_ userID: String, to workoutID: String) async throws
    func respondToInvite(_ inviteID: String, accept: Bool) async throws
    func fetchMyInvites() async throws -> [GroupWorkoutInvite]
    
    // MARK: - Calendar Integration
    
    func addToCalendar(_ workout: GroupWorkout) async throws
    func removeFromCalendar(_ workout: GroupWorkout) async throws
    
    // MARK: - Real-time Updates
    
    var workoutUpdates: AnyPublisher<GroupWorkoutUpdate, Never> { get }
}

// MARK: - Supporting Types

struct WorkoutFilters {
    let workoutTypes: [String]?
    let dateRange: DateRange?
    let maxDistance: Double? // in kilometers
    let tags: [String]?
    
    struct DateRange {
        let start: Date
        let end: Date
    }
}

// MARK: - Update Event

enum GroupWorkoutUpdate {
    case created(GroupWorkout)
    case updated(GroupWorkout)
    case deleted(String)
    case participantJoined(workoutID: String, participant: GroupWorkoutParticipant)
    case participantLeft(workoutID: String, userID: String)
    case participantDataUpdated(workoutID: String, participant: GroupWorkoutParticipant)
    case statusChanged(workoutID: String, status: GroupWorkoutStatus)
}
