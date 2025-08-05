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
        
        guard let currentUserId = try? await cloudKitManager.getCurrentUserID() else {
            // If not authenticated, only return public workouts
            let predicate = GroupWorkoutQueryBuilder.publicUpcomingWorkoutsQuery()
            return try await fetchWorkouts(with: predicate, limit: limit)
        }
        
        let now = Date()
        var allWorkouts: [GroupWorkout] = []
        var workoutIds = Set<String>()
        
        // 1. Get all public upcoming workouts
        let publicPredicate = GroupWorkoutQueryBuilder.publicUpcomingWorkoutsQuery(now: now)
        let publicWorkouts = try await fetchWorkouts(with: publicPredicate, limit: limit)
        
        for workout in publicWorkouts {
            if !workoutIds.contains(workout.id) {
                workoutIds.insert(workout.id)
                allWorkouts.append(workout)
            }
        }
        
        // 2. Get private workouts where user is the host
        let hostPredicate = GroupWorkoutQueryBuilder.privateHostWorkoutsQuery(userId: currentUserId, now: now)
        FameFitLogger.debug("Fetching host workouts with predicate: \(hostPredicate)", category: FameFitLogger.social)
        
        do {
            let hostWorkouts = try await fetchWorkouts(with: hostPredicate, limit: limit)
            FameFitLogger.debug("Found \(hostWorkouts.count) host workouts", category: FameFitLogger.social)
            
            for workout in hostWorkouts {
                if !workoutIds.contains(workout.id) {
                    workoutIds.insert(workout.id)
                    allWorkouts.append(workout)
                }
            }
        } catch {
            FameFitLogger.error("Failed to fetch host workouts", error: error, category: FameFitLogger.social)
            // Continue with other queries even if this fails
        }
        
        // 3. Get private workouts where user is a participant
        let participantPredicate = GroupWorkoutQueryBuilder.participantRecordsForUserQuery(userId: currentUserId)
        FameFitLogger.debug("Fetching participant records with predicate: \(participantPredicate)", category: FameFitLogger.social)
        
        let participantRecords = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: participantPredicate,
            sortDescriptors: nil,
            limit: 200
        )
        
        FameFitLogger.debug("Found \(participantRecords.count) participant records for user", category: FameFitLogger.social)
        
        if !participantRecords.isEmpty {
            // Get the workout IDs from participant records
            let participantWorkoutIds = participantRecords.compactMap { record -> String? in
                if let reference = record["groupWorkoutID"] as? CKRecord.Reference {
                    return reference.recordID.recordName
                }
                // Also try as string in case it's stored differently
                return record["groupWorkoutID"] as? String
            }
            
            FameFitLogger.debug("User is participant in \(participantWorkoutIds.count) workouts", category: FameFitLogger.social)
            
            // Fetch upcoming private workouts and filter by participant IDs
            let privatePredicate = GroupWorkoutQueryBuilder.privateUpcomingWorkoutsQuery(now: now)
            let privateWorkouts = try await fetchWorkouts(with: privatePredicate, limit: 500)
            
            FameFitLogger.debug("Found \(privateWorkouts.count) total upcoming private workouts", category: FameFitLogger.social)
            
            // Filter for workouts where user is a participant
            let participantWorkouts = privateWorkouts.filter { workout in
                participantWorkoutIds.contains(workout.id)
            }
            
            FameFitLogger.debug("Found \(participantWorkouts.count) upcoming private workouts where user is participant", category: FameFitLogger.social)
            
            for workout in participantWorkouts {
                if !workoutIds.contains(workout.id) {
                    workoutIds.insert(workout.id)
                    allWorkouts.append(workout)
                }
            }
        }
        
        // Sort and limit
        return Array(allWorkouts
            .sorted { $0.scheduledStart < $1.scheduledStart }
            .prefix(limit))
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
        let record = try await cloudKitManager.database.record(for: recordID)
        
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