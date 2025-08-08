//
//  GroupWorkoutQueryBuilder.swift
//  FameFit
//
//  Centralized query builder for GroupWorkout CloudKit queries
//  Ensures consistent query logic across all services
//

import CloudKit
import Foundation

enum GroupWorkoutQueryBuilder {
    // MARK: - Reference Helpers
    
    /// Creates a CKRecord.Reference from a workout ID string
    static func workoutReference(from workoutID: String) -> CKRecord.Reference {
        let recordID = CKRecord.ID(recordName: workoutID)
        return CKRecord.Reference(recordID: recordID, action: .none)
    }
    
    // MARK: - Workout Queries
    
    /// Query for public upcoming workouts (includes started but not ended)
    static func publicUpcomingWorkoutsQuery(now: Date = Date()) -> NSPredicate {
        NSPredicate(
            format: "isPublic == 1 AND scheduledEnd > %@ AND status != %@",
            now as NSDate,
            GroupWorkoutStatus.completed.rawValue
        )
    }
    
    /// Query for private workouts where user is host
    static func privateHostWorkoutsQuery(userID: String, now: Date = Date()) -> NSPredicate {
        NSPredicate(
            format: "hostID == %@ AND scheduledEnd > %@ AND isPublic == 0 AND status != %@",
            userID,
            now as NSDate,
            GroupWorkoutStatus.completed.rawValue
        )
    }
    
    /// Query for all private workouts (used with participant filtering)
    static func privateUpcomingWorkoutsQuery(now: Date = Date()) -> NSPredicate {
        NSPredicate(
            format: "scheduledEnd > %@ AND isPublic == 0 AND status != %@",
            now as NSDate,
            GroupWorkoutStatus.completed.rawValue
        )
    }
    
    /// Query for active workouts
    static func activeWorkoutsQuery() -> NSPredicate {
        NSPredicate(format: "status == %@", GroupWorkoutStatus.active.rawValue)
    }
    
    /// Query for workout by ID
    static func workoutByIDQuery(workoutID: String) -> NSPredicate {
        NSPredicate(format: "recordName == %@", workoutID)
    }
    
    /// Query for workouts by host
    static func workoutsByHostQuery(userID: String) -> NSPredicate {
        NSPredicate(format: "hostID == %@", userID)
    }
    
    // MARK: - Participant Queries
    
    /// Query for participants of a specific workout
    static func participantsForWorkoutQuery(workoutID: String) -> NSPredicate {
        let workoutRef = workoutReference(from: workoutID)
        return NSPredicate(format: "groupWorkoutID == %@", workoutRef)
    }
    
    /// Query for all participant records for a user
    static func participantRecordsForUserQuery(userID: String) -> NSPredicate {
        NSPredicate(format: "userID == %@", userID)
    }
    
    /// Query for specific participant in a workout
    static func participantInWorkoutQuery(workoutID: String, userID: String) -> NSPredicate {
        let workoutRef = workoutReference(from: workoutID)
        return NSPredicate(
            format: "groupWorkoutID == %@ AND userID == %@",
            workoutRef,
            userID
        )
    }
    
    // MARK: - Invite Queries
    
    /// Query for invites to a specific workout
    static func invitesForWorkoutQuery(workoutID: String) -> NSPredicate {
        let workoutRef = workoutReference(from: workoutID)
        return NSPredicate(format: "groupWorkoutID == %@", workoutRef)
    }
    
    /// Query for user's pending invites
    static func userInvitesQuery(userID: String, now: Date = Date()) -> NSPredicate {
        NSPredicate(
            format: "invitedUser == %@ AND expiresAt > %@",
            userID,
            now as NSDate
        )
    }
    
    // MARK: - Sort Descriptors
    
    static var scheduledStartAscending: NSSortDescriptor {
        NSSortDescriptor(key: "scheduledStart", ascending: true)
    }
    
    static var scheduledStartDescending: NSSortDescriptor {
        NSSortDescriptor(key: "scheduledStart", ascending: false)
    }
    
    static var joinedAtAscending: NSSortDescriptor {
        NSSortDescriptor(key: "joinedTimestamp", ascending: true)
    }
    
    static var invitedAtDescending: NSSortDescriptor {
        NSSortDescriptor(key: "createdTimestamp", ascending: false)
    }
}
