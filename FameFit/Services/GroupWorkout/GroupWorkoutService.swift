//
//  GroupWorkoutService.swift
//  FameFit
//
//  Consolidated service for all group workout operations
//  Split into extensions for better organization:
//  - WorkoutManagement: CRUD operations
//  - Participants: Participant management
//  - Discovery: Fetching and searching
//  - Invites: Invite management
//  - Calendar: Calendar integration
//  - Private+Helpers: Internal helpers
//

import CloudKit
import Combine
import EventKit
import Foundation
import HealthKit

/// Main service for managing group workouts
/// Implements thread-safe operations with proper error handling
final class GroupWorkoutService: GroupWorkoutServiceProtocol, @unchecked Sendable {
    // MARK: - Properties
    
    let cloudKitManager: any CloudKitManaging
    let userProfileService: any UserProfileServicing
    let notificationManager: any NotificationManaging
    let rateLimiter: any RateLimitingServicing
    let eventStore = EKEventStore()
    var workoutProcessor: WorkoutProcessor?
    
    // Publishers
    private let workoutUpdatesSubject = PassthroughSubject<GroupWorkoutUpdate, Never>()
    var workoutUpdates: AnyPublisher<GroupWorkoutUpdate, Never> {
        workoutUpdatesSubject.eraseToAnyPublisher()
    }
    
    // Cache - Thread-safe with actor
    let cache = GroupWorkoutCache()
    let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init(
        cloudKitManager: any CloudKitManaging,
        userProfileService: any UserProfileServicing,
        notificationManager: any NotificationManaging,
        rateLimiter: any RateLimitingServicing
    ) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        self.rateLimiter = rateLimiter
        
        Task {
            await setupSubscriptions()
        }
    }
    
    // MARK: - Internal Methods
    
    /// Send workout update to subscribers
    func sendUpdate(_ update: GroupWorkoutUpdate) {
        workoutUpdatesSubject.send(update)
    }
}

// MARK: - Errors

enum GroupWorkoutError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case notParticipant
    case workoutNotFound
    case workoutFull
    case cannotJoin
    case invalidWorkout(String)
    case invalidJoinCode
    case inviteNotFound
    case hostCannotLeave
    case saveFailed
    case updateFailed
    case fetchFailed
    case calendarAccessDenied
    case calendarSaveFailed
    case calendarRemoveFailed
    case calendarEventNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "You must be signed in to manage group workouts"
        case .notAuthorized:
            "You are not authorized to perform this action"
        case .notParticipant:
            "You are not a participant in this workout"
        case .workoutNotFound:
            "Group workout not found"
        case .workoutFull:
            "This workout is full"
        case .cannotJoin:
            "Cannot join this workout"
        case let .invalidWorkout(reason):
            "Invalid workout: \(reason)"
        case .invalidJoinCode:
            "Invalid join code"
        case .inviteNotFound:
            "Invite not found or expired"
        case .hostCannotLeave:
            "Host cannot leave workout. Cancel it instead."
        case .saveFailed:
            "Failed to save workout"
        case .updateFailed:
            "Failed to update workout"
        case .fetchFailed:
            "Failed to fetch workouts"
        case .calendarAccessDenied:
            "Calendar access denied. Please enable in Settings."
        case .calendarSaveFailed:
            "Failed to save to calendar"
        case .calendarRemoveFailed:
            "Failed to remove from calendar"
        case .calendarEventNotFound:
            "Calendar event not found"
        }
    }
}