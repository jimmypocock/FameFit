//
//  GroupWorkoutService+Discovery.swift
//  FameFit
//
//  Workout discovery and fetching operations for GroupWorkoutService
//

import CloudKit
import Foundation

extension GroupWorkoutService {
    // MARK: - Discovery
    
    func fetchUpcomingWorkouts(limit: Int) async throws -> [GroupWorkout] {
        FameFitLogger.info("Fetching upcoming workouts", category: FameFitLogger.social)
        
        let now = Date()
        
        guard let currentUserId = try? await cloudKitManager.getCurrentUserID() else {
            // Non-authenticated: only show public workouts
            let predicate = NSPredicate(format: 
                "isPublic == 1 AND scheduledEnd > %@ AND status == %@",
                now as NSDate, "scheduled"
            )
            return try await fetchWorkouts(with: predicate, limit: limit)
        }
        
        // For authenticated users, we need to fetch all scheduled workouts and filter client-side
        // because CloudKit doesn't support complex OR predicates
        let predicate = NSPredicate(format: 
            "scheduledEnd > %@ AND status == %@",
            now as NSDate, "scheduled"
        )
        
        FameFitLogger.debug("Fetching all scheduled workouts, will filter client-side", category: FameFitLogger.social)
        
        // Fetch more workouts since we'll filter client-side
        let allWorkouts = try await fetchWorkouts(with: predicate, limit: limit * 3)
        
        // Filter client-side: show workouts that are public, hosted by user, or user is participant
        let filteredWorkouts = allWorkouts.filter { workout in
            workout.isPublic || 
            workout.hostId == currentUserId || 
            workout.participantIDs.contains(currentUserId)
        }
        
        // Take only the requested limit after filtering
        let limitedWorkouts = Array(filteredWorkouts.prefix(limit))
        
        FameFitLogger.info("Found \(allWorkouts.count) total, filtered to \(limitedWorkouts.count) relevant workouts", category: FameFitLogger.social)
        
        // Log details for debugging
        for workout in limitedWorkouts {
            FameFitLogger.debug("Workout: \(workout.name) - Host: \(workout.hostId) - Public: \(workout.isPublic) - Status: \(workout.status.rawValue) - ParticipantIDs: \(workout.participantIDs)", category: FameFitLogger.social)
        }
        
        return limitedWorkouts
    }
    
    func fetchActiveWorkouts() async throws -> [GroupWorkout] {
        FameFitLogger.info("Fetching active workouts", category: FameFitLogger.social)
        
        let predicate = GroupWorkoutQueryBuilder.activeWorkoutsQuery()
        FameFitLogger.debug("Active workouts predicate: \(predicate)", category: FameFitLogger.social)
        
        let workouts = try await fetchWorkouts(with: predicate)
        FameFitLogger.info("Found \(workouts.count) active workouts", category: FameFitLogger.social)
        
        return workouts
    }
    
    func fetchMyWorkouts() async throws -> [GroupWorkout] {
        FameFitLogger.info("Fetching my workouts", category: FameFitLogger.social)
        
        guard let userId = try? await cloudKitManager.getCurrentUserID() else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        let predicate = GroupWorkoutQueryBuilder.workoutsByHostQuery(userId: userId)
        return try await fetchWorkouts(with: predicate, limit: 100)
    }
    
    func fetchWorkout(_ workoutId: String) async throws -> GroupWorkout {
        // Check cache first
        if let cached = await getCachedWorkout(workoutId) {
            return cached
        }
        
        let recordID = CKRecord.ID(recordName: workoutId)
        
        // Fetch using a query to ensure we use the public database
        let predicate = NSPredicate(format: "recordID == %@", recordID)
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkouts",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        guard let record = records.first else {
            throw GroupWorkoutError.workoutNotFound
        }
        
        guard let workout = GroupWorkout(from: record) else {
            throw GroupWorkoutError.workoutNotFound
        }
        
        // Cache the workout
        await cacheWorkout(workout)
        
        return workout
    }
    
    func fetchPublicWorkouts(tags: [String]?, limit: Int) async throws -> [GroupWorkout] {
        FameFitLogger.info("Fetching public workouts", category: FameFitLogger.social)
        
        var predicateFormat = "isPublic == 1 AND scheduledStart > %@"
        var args: [Any] = [Date() as NSDate]
        
        if let tags = tags, !tags.isEmpty {
            predicateFormat += " AND ANY tags IN %@"
            args.append(tags)
        }
        
        let predicate = NSPredicate(format: predicateFormat, argumentArray: args)
        return try await fetchWorkouts(with: predicate, limit: limit)
    }
    
    func searchWorkouts(query: String, filters: WorkoutFilters?) async throws -> [GroupWorkout] {
        var predicateFormat = "(name CONTAINS[cd] %@ OR notes CONTAINS[cd] %@ OR location CONTAINS[cd] %@)"
        var args: [Any] = [query, query, query]
        
        if let filters = filters {
            if let types = filters.workoutTypes, !types.isEmpty {
                predicateFormat += " AND workoutType IN %@"
                args.append(types)
            }
            
            if let dateRange = filters.dateRange {
                predicateFormat += " AND scheduledStart >= %@ AND scheduledStart <= %@"
                args.append(dateRange.start as NSDate)
                args.append(dateRange.end as NSDate)
            }
            
            if let tags = filters.tags, !tags.isEmpty {
                predicateFormat += " AND ANY tags IN %@"
                args.append(tags)
            }
        }
        
        let predicate = NSPredicate(format: predicateFormat, argumentArray: args)
        return try await fetchWorkouts(with: predicate, limit: 50)
    }
    
    // MARK: - Internal Fetch Helper
    
    func fetchWorkouts(with predicate: NSPredicate, limit: Int = 50) async throws -> [GroupWorkout] {
        let query = CKQuery(recordType: "GroupWorkouts", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "scheduledStart", ascending: true)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkouts",
            predicate: predicate,
            sortDescriptors: query.sortDescriptors,
            limit: limit
        )
        
        return records.compactMap { GroupWorkout(from: $0) }
    }
}