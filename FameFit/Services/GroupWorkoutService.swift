//
//  GroupWorkoutService.swift
//  FameFit
//
//  Service for managing group workout sessions
//

import Foundation
import CloudKit
import Combine
import HealthKit

// MARK: - Protocol

protocol GroupWorkoutServicing {
    // Host Operations
    func createGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout
    func updateGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout
    func cancelGroupWorkout(workoutId: String) async throws
    func startGroupWorkout(workoutId: String) async throws -> GroupWorkout
    func completeGroupWorkout(workoutId: String) async throws -> GroupWorkout
    
    // Participant Operations
    func joinGroupWorkout(workoutId: String) async throws -> GroupWorkout
    func joinWithCode(_ code: String) async throws -> GroupWorkout
    func leaveGroupWorkout(workoutId: String) async throws
    func updateParticipantData(workoutId: String, data: GroupWorkoutData) async throws
    
    // Fetching
    func fetchUpcomingWorkouts(limit: Int) async throws -> [GroupWorkout]
    func fetchActiveWorkouts() async throws -> [GroupWorkout]
    func fetchMyWorkouts(userId: String) async throws -> [GroupWorkout]
    func fetchWorkout(workoutId: String) async throws -> GroupWorkout
    func searchWorkouts(query: String, workoutType: HKWorkoutActivityType?) async throws -> [GroupWorkout]
    
    // Real-time Updates
    var activeWorkoutUpdates: AnyPublisher<GroupWorkoutUpdate, Never> { get }
}

// MARK: - Service Implementation

final class GroupWorkoutService: GroupWorkoutServicing {
    
    // MARK: - Properties
    
    private let publicDatabase: CKDatabase
    private let privateDatabase: CKDatabase
    private let cloudKitManager: any CloudKitManaging
    private let userProfileService: any UserProfileServicing
    private let notificationManager: any NotificationManaging
    private let rateLimiter: any RateLimitingServicing
    
    // Publishers
    private let activeWorkoutUpdatesSubject = PassthroughSubject<GroupWorkoutUpdate, Never>()
    var activeWorkoutUpdates: AnyPublisher<GroupWorkoutUpdate, Never> {
        activeWorkoutUpdatesSubject.eraseToAnyPublisher()
    }
    
    // Cache
    private var workoutCache: [String: (workout: GroupWorkout, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init(cloudKitManager: any CloudKitManaging,
         userProfileService: any UserProfileServicing,
         notificationManager: any NotificationManaging,
         rateLimiter: any RateLimitingServicing) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        self.rateLimiter = rateLimiter
        self.publicDatabase = CKContainer.default().publicCloudDatabase
        self.privateDatabase = CKContainer.default().privateCloudDatabase
        
        // Start listening for real-time updates
        setupRealTimeUpdates()
    }
    
    // MARK: - Host Operations
    
    func createGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout {
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Verify user is the host
        guard workout.hostId == userId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Check rate limiting
        _ = try await rateLimiter.checkLimit(for: .workoutPost, userId: userId)
        
        // Validate workout
        try validateWorkout(workout)
        
        // Create the workout with the host as first participant
        let hostProfile = try await userProfileService.fetchProfile(userId: userId)
        let hostParticipant = GroupWorkoutParticipant(
            userId: userId,
            displayName: hostProfile.displayName,
            profileImageURL: hostProfile.profileImageURL
        )
        
        var newWorkout = workout
        if !newWorkout.participants.contains(where: { $0.userId == userId }) {
            newWorkout.participants.append(hostParticipant)
        }
        
        // Save to CloudKit
        let record = newWorkout.toCKRecord()
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let savedWorkout = GroupWorkout(from: savedRecord) else {
                throw GroupWorkoutError.saveFailed
            }
            
            // Record action for rate limiting
            await rateLimiter.recordAction(.workoutPost, userId: userId)
            
            // Cache the workout
            cacheWorkout(savedWorkout)
            
            // Schedule reminder notification
            await scheduleWorkoutReminder(savedWorkout)
            
            return savedWorkout
        } catch {
            throw GroupWorkoutError.saveFailed
        }
    }
    
    func updateGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout {
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        // Only host can update
        guard workout.hostId == userId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Update the workout
        var updatedWorkout = workout
        updatedWorkout.updatedAt = Date()
        
        // Save to CloudKit
        let recordID = CKRecord.ID(recordName: workout.id)
        let record = updatedWorkout.toCKRecord(recordID: recordID)
        
        do {
            let savedRecord = try await publicDatabase.save(record)
            guard let savedWorkout = GroupWorkout(from: savedRecord) else {
                throw GroupWorkoutError.updateFailed
            }
            
            // Update cache
            cacheWorkout(savedWorkout)
            
            // Notify participants of update
            await notifyParticipantsOfUpdate(savedWorkout)
            
            return savedWorkout
        } catch {
            throw GroupWorkoutError.updateFailed
        }
    }
    
    func cancelGroupWorkout(workoutId: String) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId: workoutId)
        
        // Only host can cancel
        guard workout.hostId == userId else {
            throw GroupWorkoutError.notAuthorized
        }
        
        // Update status
        workout.status = .cancelled
        workout.updatedAt = Date()
        
        // Save update
        _ = try await updateGroupWorkout(workout)
        
        // Notify all participants
        await notifyParticipantsOfCancellation(workout)
    }
    
    func startGroupWorkout(workoutId: String) async throws -> GroupWorkout {
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId: workoutId)
        
        // Verify user is host or participant
        guard workout.hostId == userId || workout.participantIds.contains(userId) else {
            throw GroupWorkoutError.notParticipant
        }
        
        // Update status
        workout.status = .active
        workout.updatedAt = Date()
        
        // Update participant status
        if let index = workout.participants.firstIndex(where: { $0.userId == userId }) {
            workout.participants[index].status = .active
            workout.participants[index].workoutData = GroupWorkoutData(
                startTime: Date(),
                totalEnergyBurned: 0,
                lastUpdated: Date()
            )
        }
        
        // Save update
        let updatedWorkout = try await updateGroupWorkout(workout)
        
        // Send real-time update
        let update = GroupWorkoutUpdate(
            workoutId: workoutId,
            participantId: userId,
            updateType: .started,
            data: workout.participants.first(where: { $0.userId == userId })?.workoutData,
            timestamp: Date()
        )
        activeWorkoutUpdatesSubject.send(update)
        
        // Notify other participants
        await notifyParticipantsOfStart(updatedWorkout, startedBy: userId)
        
        return updatedWorkout
    }
    
    func completeGroupWorkout(workoutId: String) async throws -> GroupWorkout {
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId: workoutId)
        
        // Update participant status
        if let index = workout.participants.firstIndex(where: { $0.userId == userId }) {
            workout.participants[index].status = .completed
            if var workoutData = workout.participants[index].workoutData {
                workoutData.endTime = Date()
                workout.participants[index].workoutData = workoutData
            }
        }
        
        // Check if all participants completed
        let allCompleted = workout.participants.allSatisfy { 
            $0.status == .completed || $0.status == .dropped 
        }
        
        if allCompleted || workout.hostId == userId {
            workout.status = .completed
        }
        
        workout.updatedAt = Date()
        
        // Save update
        let updatedWorkout = try await updateGroupWorkout(workout)
        
        // Send real-time update
        let update = GroupWorkoutUpdate(
            workoutId: workoutId,
            participantId: userId,
            updateType: .completed,
            data: workout.participants.first(where: { $0.userId == userId })?.workoutData,
            timestamp: Date()
        )
        activeWorkoutUpdatesSubject.send(update)
        
        // Award XP for group workout completion
        await awardGroupWorkoutXP(updatedWorkout, for: userId)
        
        return updatedWorkout
    }
    
    // MARK: - Participant Operations
    
    func joinGroupWorkout(workoutId: String) async throws -> GroupWorkout {
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId: workoutId)
        
        // Check if already joined
        guard !workout.participantIds.contains(userId) else {
            return workout
        }
        
        // Check capacity
        guard workout.hasSpace else {
            throw GroupWorkoutError.workoutFull
        }
        
        // Check if can join
        guard workout.status.canJoin else {
            throw GroupWorkoutError.cannotJoin
        }
        
        // Check rate limiting
        _ = try await rateLimiter.checkLimit(for: .followRequest, userId: userId)
        
        // Add participant
        let userProfile = try await userProfileService.fetchProfile(userId: userId)
        let participant = GroupWorkoutParticipant(
            userId: userId,
            displayName: userProfile.displayName,
            profileImageURL: userProfile.profileImageURL
        )
        
        workout.participants.append(participant)
        workout.updatedAt = Date()
        
        // Save update
        let updatedWorkout = try await updateGroupWorkout(workout)
        
        // Record action
        await rateLimiter.recordAction(.followRequest, userId: userId)
        
        // Send notification to host
        await notifyHostOfNewParticipant(updatedWorkout, participantId: userId)
        
        // Send real-time update
        let update = GroupWorkoutUpdate(
            workoutId: workoutId,
            participantId: userId,
            updateType: .joined,
            data: nil,
            timestamp: Date()
        )
        activeWorkoutUpdatesSubject.send(update)
        
        return updatedWorkout
    }
    
    func joinWithCode(_ code: String) async throws -> GroupWorkout {
        // Find workout by join code
        let predicate = NSPredicate(format: "joinCode == %@", code)
        let query = CKQuery(recordType: "GroupWorkouts", predicate: predicate)
        
        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: 1)
            guard let record = try? results.matchResults.first?.1.get(),
                  let workout = GroupWorkout(from: record) else {
                throw GroupWorkoutError.invalidJoinCode
            }
            
            return try await joinGroupWorkout(workoutId: workout.id)
        } catch {
            throw GroupWorkoutError.invalidJoinCode
        }
    }
    
    func leaveGroupWorkout(workoutId: String) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId: workoutId)
        
        // Find and update participant
        guard let index = workout.participants.firstIndex(where: { $0.userId == userId }) else {
            throw GroupWorkoutError.notParticipant
        }
        
        // Can't leave if host (must cancel instead)
        guard workout.hostId != userId else {
            throw GroupWorkoutError.hostCannotLeave
        }
        
        // Update status
        workout.participants[index].status = .dropped
        workout.updatedAt = Date()
        
        // Save update
        _ = try await updateGroupWorkout(workout)
        
        // Send real-time update
        let update = GroupWorkoutUpdate(
            workoutId: workoutId,
            participantId: userId,
            updateType: .dropped,
            data: nil,
            timestamp: Date()
        )
        activeWorkoutUpdatesSubject.send(update)
    }
    
    func updateParticipantData(workoutId: String, data: GroupWorkoutData) async throws {
        guard let userId = cloudKitManager.currentUserID else {
            throw GroupWorkoutError.notAuthenticated
        }
        
        var workout = try await fetchWorkout(workoutId: workoutId)
        
        // Find participant
        guard let index = workout.participants.firstIndex(where: { $0.userId == userId }) else {
            throw GroupWorkoutError.notParticipant
        }
        
        // Update data
        workout.participants[index].workoutData = data
        workout.updatedAt = Date()
        
        // Save update (with rate limiting for frequent updates)
        if shouldUpdateCloudKit(for: workoutId) {
            _ = try await updateGroupWorkout(workout)
        }
        
        // Always send real-time update
        let update = GroupWorkoutUpdate(
            workoutId: workoutId,
            participantId: userId,
            updateType: .progress,
            data: data,
            timestamp: Date()
        )
        activeWorkoutUpdatesSubject.send(update)
    }
    
    // MARK: - Fetching
    
    func fetchUpcomingWorkouts(limit: Int = 20) async throws -> [GroupWorkout] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "status == %@", GroupWorkoutStatus.scheduled.rawValue),
            NSPredicate(format: "scheduledStart > %@", Date() as NSDate),
            NSPredicate(format: "isPublic == %@", NSNumber(value: true))
        ])
        
        return try await fetchWorkouts(with: predicate, limit: limit)
    }
    
    func fetchActiveWorkouts() async throws -> [GroupWorkout] {
        let predicate = NSPredicate(format: "status == %@", GroupWorkoutStatus.active.rawValue)
        return try await fetchWorkouts(with: predicate)
    }
    
    func fetchMyWorkouts(userId: String) async throws -> [GroupWorkout] {
        // Fetch workouts where user is host or participant
        let hostPredicate = NSPredicate(format: "hostId == %@", userId)
        let participantPredicate = NSPredicate(format: "ANY participants.userId == %@", userId)
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [hostPredicate, participantPredicate])
        
        return try await fetchWorkouts(with: predicate, limit: 50)
    }
    
    func fetchWorkout(workoutId: String) async throws -> GroupWorkout {
        // Check cache first
        if let cached = getCachedWorkout(workoutId) {
            return cached
        }
        
        let recordID = CKRecord.ID(recordName: workoutId)
        
        do {
            let record = try await publicDatabase.record(for: recordID)
            guard let workout = GroupWorkout(from: record) else {
                throw GroupWorkoutError.workoutNotFound
            }
            
            // Cache the workout
            cacheWorkout(workout)
            
            return workout
        } catch {
            throw GroupWorkoutError.workoutNotFound
        }
    }
    
    func searchWorkouts(query: String, workoutType: HKWorkoutActivityType? = nil) async throws -> [GroupWorkout] {
        var predicates: [NSPredicate] = [
            NSPredicate(format: "isPublic == %@", NSNumber(value: true)),
            NSPredicate(format: "status == %@", GroupWorkoutStatus.scheduled.rawValue)
        ]
        
        // Add search predicate
        if !query.isEmpty {
            let searchPredicates = [
                NSPredicate(format: "name CONTAINS[cd] %@", query),
                NSPredicate(format: "description CONTAINS[cd] %@", query),
                NSPredicate(format: "ANY tags CONTAINS[cd] %@", query)
            ]
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: searchPredicates))
        }
        
        // Add workout type filter
        if let workoutType = workoutType {
            predicates.append(NSPredicate(format: "workoutType == %d", workoutType.rawValue))
        }
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        return try await fetchWorkouts(with: predicate)
    }
    
    // MARK: - Private Methods
    
    private func fetchWorkouts(with predicate: NSPredicate, limit: Int = 50) async throws -> [GroupWorkout] {
        let query = CKQuery(recordType: "GroupWorkouts", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "scheduledStart", ascending: true)]
        
        do {
            let results = try await publicDatabase.records(matching: query, resultsLimit: limit)
            return results.matchResults.compactMap { _, result in
                try? result.get()
            }.compactMap { GroupWorkout(from: $0) }
        } catch {
            throw GroupWorkoutError.fetchFailed
        }
    }
    
    private func validateWorkout(_ workout: GroupWorkout) throws {
        // Validate name
        guard !workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GroupWorkoutError.invalidWorkout("Name is required")
        }
        
        // Validate duration
        guard workout.duration >= 300 else { // Minimum 5 minutes
            throw GroupWorkoutError.invalidWorkout("Workout must be at least 5 minutes")
        }
        
        guard workout.duration <= 14400 else { // Maximum 4 hours
            throw GroupWorkoutError.invalidWorkout("Workout cannot exceed 4 hours")
        }
        
        // Validate scheduled time
        guard workout.scheduledStart > Date() else {
            throw GroupWorkoutError.invalidWorkout("Workout must be scheduled in the future")
        }
        
        // Validate participants
        guard workout.maxParticipants >= 2 && workout.maxParticipants <= 50 else {
            throw GroupWorkoutError.invalidWorkout("Participants must be between 2 and 50")
        }
    }
    
    // MARK: - Caching
    
    private func cacheWorkout(_ workout: GroupWorkout) {
        workoutCache[workout.id] = (workout, Date())
    }
    
    private func getCachedWorkout(_ workoutId: String) -> GroupWorkout? {
        guard let cached = workoutCache[workoutId] else { return nil }
        
        // Check if cache expired
        if Date().timeIntervalSince(cached.timestamp) > cacheExpiration {
            workoutCache.removeValue(forKey: workoutId)
            return nil
        }
        
        return cached.workout
    }
    
    private var updateThrottleCache: [String: Date] = [:]
    
    private func shouldUpdateCloudKit(for workoutId: String) -> Bool {
        let now = Date()
        let throttleInterval: TimeInterval = 5 // 5 seconds between updates
        
        if let lastUpdate = updateThrottleCache[workoutId] {
            if now.timeIntervalSince(lastUpdate) < throttleInterval {
                return false
            }
        }
        
        updateThrottleCache[workoutId] = now
        return true
    }
    
    // MARK: - Real-time Updates
    
    private func setupRealTimeUpdates() {
        // In a real app, this would use CloudKit subscriptions
        // For now, we'll rely on polling and manual updates
    }
    
    // MARK: - Notifications
    
    private func scheduleWorkoutReminder(_ workout: GroupWorkout) async {
        // Schedule reminder 15 minutes before workout
        let reminderDate = workout.scheduledStart.addingTimeInterval(-900)
        
        guard reminderDate > Date() else { return }
        
        // For now, send immediate notifications to participants
        // TODO: Add scheduled notification support
        for _ in workout.participants {
            await notificationManager.notifyFeatureAnnouncement(
                feature: "Group Workout Reminder",
                description: "\(workout.name) starts in 15 minutes! Get ready to crush it! 🏃‍♂️"
            )
        }
    }
    
    private func notifyParticipantsOfUpdate(_ workout: GroupWorkout) async {
        // Notify all participants except host
        for participant in workout.participants where participant.userId != workout.hostId {
            await notificationManager.notifyFeatureAnnouncement(
                feature: "Workout Update",
                description: "\(workout.name) has been updated. Check the details!"
            )
        }
    }
    
    private func notifyParticipantsOfCancellation(_ workout: GroupWorkout) async {
        // Notify all participants except host about cancellation
        for participant in workout.participants where participant.userId != workout.hostId {
            await notificationManager.notifyFeatureAnnouncement(
                feature: "Workout Cancelled",
                description: "Unfortunately, \(workout.name) has been cancelled."
            )
        }
    }
    
    private func notifyParticipantsOfStart(_ workout: GroupWorkout, startedBy userId: String) async {
        guard let starter = try? await userProfileService.fetchProfile(userId: userId) else { return }
        
        // Notify other participants that the workout has started
        for participant in workout.participants where participant.userId != userId {
            await notificationManager.notifyFeatureAnnouncement(
                feature: "Workout Started! 🚀",
                description: "\(starter.displayName) just started \(workout.name). Join now!"
            )
        }
    }
    
    private func notifyHostOfNewParticipant(_ workout: GroupWorkout, participantId: String) async {
        guard let participant = try? await userProfileService.fetchProfile(userId: participantId) else { return }
        
        // Notify host about new participant
        // Since we can't send to specific user, we'll use the general announcement
        // In production, this would be sent only to the host
        await notificationManager.notifyFeatureAnnouncement(
            feature: "New Participant! 👥",
            description: "\(participant.displayName) just joined \(workout.name)"
        )
    }
    
    private func awardGroupWorkoutXP(_ workout: GroupWorkout, for userId: String) async {
        // Award bonus XP for group workouts
        let baseXP = 20 // Base XP for completing group workout
        let bonusXP = min(workout.participants.count * 5, 50) // Up to 50 bonus XP
        _ = baseXP + bonusXP
        
        // Award XP through CloudKit manager
        // This would need to be implemented in CloudKitManager
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
    case hostCannotLeave
    case saveFailed
    case updateFailed
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to manage group workouts"
        case .notAuthorized:
            return "You are not authorized to perform this action"
        case .notParticipant:
            return "You are not a participant in this workout"
        case .workoutNotFound:
            return "Group workout not found"
        case .workoutFull:
            return "This workout is full"
        case .cannotJoin:
            return "Cannot join this workout"
        case .invalidWorkout(let reason):
            return "Invalid workout: \(reason)"
        case .invalidJoinCode:
            return "Invalid join code"
        case .hostCannotLeave:
            return "Host cannot leave workout. Cancel it instead."
        case .saveFailed:
            return "Failed to save workout"
        case .updateFailed:
            return "Failed to update workout"
        case .fetchFailed:
            return "Failed to fetch workouts"
        }
    }
}