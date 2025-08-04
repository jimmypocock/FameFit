//
//  GroupWorkoutSchedulingService.swift
//  FameFit
//
//  Service for managing group workout scheduling
//

import CloudKit
import Combine
import EventKit
import Foundation

// MARK: - Type Aliases
// Use the shared GroupWorkoutInvite struct directly

// MARK: - Group Workout Scheduling Service Protocol

protocol GroupWorkoutSchedulingServicing: AnyObject {
    // Create & Update
    func createGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout
    func updateGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout
    func deleteGroupWorkout(_ workoutId: String) async throws
    
    // Participants
    func joinGroupWorkout(_ workoutId: String, status: ParticipantStatus) async throws
    func leaveGroupWorkout(_ workoutId: String) async throws
    func updateParticipantStatus(_ workoutId: String, status: ParticipantStatus) async throws
    func getParticipants(_ workoutId: String) async throws -> [GroupWorkoutParticipant]
    
    // Discovery
    func fetchUpcomingWorkouts(limit: Int) async throws -> [GroupWorkout]
    func fetchMyWorkouts() async throws -> [GroupWorkout]
    func fetchPublicWorkouts(tags: [String]?, limit: Int) async throws -> [GroupWorkout]
    func searchWorkouts(query: String, filters: WorkoutFilters?) async throws -> [GroupWorkout]
    
    // Invites
    func inviteUser(_ userId: String, to workoutId: String) async throws
    func respondToInvite(_ inviteId: String, accept: Bool) async throws
    func fetchMyInvites() async throws -> [GroupWorkoutInvite]
    
    // Calendar
    func addToCalendar(_ workout: GroupWorkout) async throws
    func removeFromCalendar(_ workout: GroupWorkout) async throws
    
    // Real-time updates
    var workoutUpdatesPublisher: AnyPublisher<GroupWorkout, Never> { get }
}

// MARK: - Workout Filters

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

// MARK: - Implementation

final class GroupWorkoutSchedulingService: GroupWorkoutSchedulingServicing {
    private let cloudKitManager: any CloudKitManaging
    private let userProfileService: UserProfileServicing
    private let notificationManager: NotificationManaging
    private let eventStore = EKEventStore()
    
    private let workoutUpdatesSubject = PassthroughSubject<GroupWorkout, Never>()
    var workoutUpdatesPublisher: AnyPublisher<GroupWorkout, Never> {
        workoutUpdatesSubject.eraseToAnyPublisher()
    }
    
    private var subscriptions: [CKSubscription] = []
    
    init(
        cloudKitManager: any CloudKitManaging,
        userProfileService: UserProfileServicing,
        notificationManager: NotificationManaging
    ) {
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        
        Task {
            await setupSubscriptions()
        }
    }
    
    // MARK: - Create & Update
    
    func createGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout {
        let record = workout.toCKRecord()
        let savedRecord = try await cloudKitManager.save(record)
        
        guard let savedWorkout = GroupWorkout(from: savedRecord) else {
            throw GroupWorkoutSchedulingError.invalidData
        }
        
        // Automatically add creator as participant
        let currentUserId = try await cloudKitManager.getCurrentUserID()
        let currentProfile = try await userProfileService.fetchCurrentUserProfile()
        
        let participant = GroupWorkoutParticipant(
            id: UUID().uuidString,
            groupWorkoutId: savedWorkout.id,
            userId: currentUserId,
            username: currentProfile.username,
            profileImageURL: currentProfile.profileImageURL,
            status: .joined
        )
        
        let participantRecord = participant.toCKRecord()
        _ = try await cloudKitManager.save(participantRecord)
        
        // Update participant count on the workout
        var workoutWithUpdatedCount = savedWorkout
        workoutWithUpdatedCount.participantCount += 1
        let updatedWorkoutRecord = workoutWithUpdatedCount.toCKRecord()
        _ = try await cloudKitManager.save(updatedWorkoutRecord)
        
        workoutUpdatesSubject.send(workoutWithUpdatedCount)
        
        return workoutWithUpdatedCount
    }
    
    func updateGroupWorkout(_ workout: GroupWorkout) async throws -> GroupWorkout {
        // Create updated workout with new timestamp
        let updatedWorkout = GroupWorkout(
            id: workout.id,
            name: workout.name,
            description: workout.description,
            workoutType: workout.workoutType,
            hostId: workout.hostId,
            participantCount: workout.participantCount,
            maxParticipants: workout.maxParticipants,
            scheduledStart: workout.scheduledStart,
            scheduledEnd: workout.scheduledEnd,
            status: workout.status,
            createdTimestamp: workout.createdTimestamp,
            modifiedTimestamp: Date(),
            isPublic: workout.isPublic,
            joinCode: workout.joinCode,
            tags: workout.tags,
            location: workout.location,
            notes: workout.notes
        )
        
        let record = updatedWorkout.toCKRecord()
        let savedRecord = try await cloudKitManager.save(record)
        
        guard let savedWorkout = GroupWorkout(from: savedRecord) else {
            throw GroupWorkoutSchedulingError.invalidData
        }
        
        workoutUpdatesSubject.send(savedWorkout)
        
        // Notify participants of update
        await notifyParticipantsOfUpdate(savedWorkout)
        
        return savedWorkout
    }
    
    func deleteGroupWorkout(_ workoutId: String) async throws {
        // Find the workout record
        let predicate = NSPredicate(format: "id == %@", workoutId)
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkouts",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        guard let record = records.first else {
            throw GroupWorkoutSchedulingError.notFound
        }
        
        // Check if current user is the creator
        let currentUserId = try await cloudKitManager.getCurrentUserID()
        guard record["hostId"] as? String == currentUserId else {
            throw GroupWorkoutSchedulingError.unauthorized
        }
        
        // Delete the workout
        try await cloudKitManager.delete(withRecordID: record.recordID)
        
        // Delete all participants
        let participantPredicate = NSPredicate(format: "groupWorkoutID == %@", workoutId)
        let participantRecords = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: participantPredicate,
            sortDescriptors: nil,
            limit: 100
        )
        
        for participantRecord in participantRecords {
            try await cloudKitManager.delete(withRecordID: participantRecord.recordID)
        }
        
        // Delete all invites
        let invitePredicate = NSPredicate(format: "groupWorkoutID == %@", workoutId)
        let inviteRecords = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: invitePredicate,
            sortDescriptors: nil,
            limit: 100
        )
        
        for inviteRecord in inviteRecords {
            try await cloudKitManager.delete(withRecordID: inviteRecord.recordID)
        }
    }
    
    // MARK: - Participants
    
    func joinGroupWorkout(_ workoutId: String, status: ParticipantStatus) async throws {
        let currentUserId = try await cloudKitManager.getCurrentUserID()
        let currentProfile = try await userProfileService.fetchCurrentUserProfile()
        
        // Check if already a participant
        let predicate = NSPredicate(
            format: "groupWorkoutId == %@ AND userId == %@",
            workoutId,
            currentUserId
        )
        
        let existingRecords = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        if let existingRecord = existingRecords.first {
            // Update status
            existingRecord["status"] = status.rawValue
            _ = try await cloudKitManager.save(existingRecord)
        } else {
            // Create new participant
            let participant = GroupWorkoutParticipant(
                id: UUID().uuidString,
                groupWorkoutId: workoutId,
                userId: currentUserId,
                username: currentProfile.username,
                profileImageURL: currentProfile.profileImageURL,
                status: .joined
            )
            
            let record = participant.toCKRecord()
            _ = try await cloudKitManager.save(record)
        }
        
        // Send notification
        await sendJoinNotification(workoutId: workoutId, status: status)
    }
    
    func leaveGroupWorkout(_ workoutId: String) async throws {
        let currentUserId = try await cloudKitManager.getCurrentUserID()
        
        let predicate = NSPredicate(
            format: "groupWorkoutId == %@ AND userId == %@",
            workoutId,
            currentUserId
        )
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        if let record = records.first {
            try await cloudKitManager.delete(withRecordID: record.recordID)
        }
    }
    
    func updateParticipantStatus(_ workoutId: String, status: ParticipantStatus) async throws {
        try await joinGroupWorkout(workoutId, status: status)
    }
    
    func getParticipants(_ workoutId: String) async throws -> [GroupWorkoutParticipant] {
        let predicate = NSPredicate(format: "groupWorkoutID == %@", workoutId)
        let sortDescriptors = [NSSortDescriptor(key: "joinedAt", ascending: true)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 100
        )
        
        return records.compactMap { GroupWorkoutParticipant(from: $0) }
    }
    
    // MARK: - Discovery
    
    func fetchUpcomingWorkouts(limit: Int) async throws -> [GroupWorkout] {
        let currentUserId = try await cloudKitManager.getCurrentUserID()
        
        // First get all workouts I'm participating in
        let participantPredicate = NSPredicate(format: "userId == %@", currentUserId)
        let participantRecords = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutParticipants",
            predicate: participantPredicate,
            sortDescriptors: nil,
            limit: 100
        )
        
        let workoutIds = participantRecords.compactMap { $0["groupWorkoutId"] as? String }
        
        guard !workoutIds.isEmpty else { return [] }
        
        // Fetch the actual workouts
        let workoutPredicate = NSPredicate(
            format: "id IN %@ AND scheduledDate > %@",
            workoutIds,
            Date() as NSDate
        )
        
        let sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: true)]
        
        let workoutRecords = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkouts",
            predicate: workoutPredicate,
            sortDescriptors: sortDescriptors,
            limit: limit
        )
        
        return workoutRecords.compactMap { GroupWorkout(from: $0) }
    }
    
    func fetchMyWorkouts() async throws -> [GroupWorkout] {
        let currentUserId = try await cloudKitManager.getCurrentUserID()
        
        let predicate = NSPredicate(format: "createdBy == %@", currentUserId)
        let sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: false)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkouts",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 100
        )
        
        return records.compactMap { GroupWorkout(from: $0) }
    }
    
    func fetchPublicWorkouts(tags: [String]?, limit: Int) async throws -> [GroupWorkout] {
        var predicateFormat = "isPublic == 1 AND scheduledDate > %@"
        var args: [Any] = [Date() as NSDate]
        
        if let tags = tags, !tags.isEmpty {
            predicateFormat += " AND ANY tags IN %@"
            args.append(tags)
        }
        
        let predicate = NSPredicate(format: predicateFormat, argumentArray: args)
        let sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: true)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkouts",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: limit
        )
        
        return records.compactMap { GroupWorkout(from: $0) }
    }
    
    func searchWorkouts(query: String, filters: WorkoutFilters?) async throws -> [GroupWorkout] {
        var predicateFormat = "(title CONTAINS[cd] %@ OR notes CONTAINS[cd] %@ OR location CONTAINS[cd] %@)"
        var args: [Any] = [query, query, query]
        
        if let filters = filters {
            if let types = filters.workoutTypes, !types.isEmpty {
                predicateFormat += " AND workoutType IN %@"
                args.append(types)
            }
            
            if let dateRange = filters.dateRange {
                predicateFormat += " AND scheduledDate >= %@ AND scheduledDate <= %@"
                args.append(dateRange.start as NSDate)
                args.append(dateRange.end as NSDate)
            }
            
            if let tags = filters.tags, !tags.isEmpty {
                predicateFormat += " AND ANY tags IN %@"
                args.append(tags)
            }
        }
        
        let predicate = NSPredicate(format: predicateFormat, argumentArray: args)
        let sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: true)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkouts",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 50
        )
        
        return records.compactMap { GroupWorkout(from: $0) }
    }
    
    // MARK: - Invites
    
    func inviteUser(_ userId: String, to workoutId: String) async throws {
        let currentUserId = try await cloudKitManager.getCurrentUserID()
        
        let invite = GroupWorkoutInvite(
            groupWorkoutId: workoutId,
            invitedBy: currentUserId,
            invitedUser: userId
        )
        
        let record = invite.toCKRecord()
        _ = try await cloudKitManager.save(record)
        
        // Send push notification
        await sendInviteNotification(to: userId, workoutId: workoutId)
    }
    
    func respondToInvite(_ inviteId: String, accept: Bool) async throws {
        // Find the invite
        let predicate = NSPredicate(format: "id == %@", inviteId)
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: nil,
            limit: 1
        )
        
        guard let inviteRecord = records.first,
              let invite = GroupWorkoutInvite(from: inviteRecord) else {
            throw GroupWorkoutSchedulingError.inviteNotFound
        }
        
        // Delete the invite
        try await cloudKitManager.delete(withRecordID: inviteRecord.recordID)
        
        // If accepted, join the workout
        if accept {
            try await joinGroupWorkout(invite.groupWorkoutId, status: .joined)
        }
    }
    
    func fetchMyInvites() async throws -> [GroupWorkoutInvite] {
        let currentUserId = try await cloudKitManager.getCurrentUserID()
        
        let predicate = NSPredicate(
            format: "invitedUser == %@ AND expiresAt > %@",
            currentUserId,
            Date() as NSDate
        )
        
        let sortDescriptors = [NSSortDescriptor(key: "invitedAt", ascending: false)]
        
        let records = try await cloudKitManager.fetchRecords(
            ofType: "GroupWorkoutInvites",
            predicate: predicate,
            sortDescriptors: sortDescriptors,
            limit: 50
        )
        
        return records.compactMap { GroupWorkoutInvite(from: $0) }
    }
    
    // MARK: - Calendar Integration
    
    func addToCalendar(_ workout: GroupWorkout) async throws {
        let status = await requestCalendarAccess()
        guard status == .fullAccess else {
            throw GroupWorkoutSchedulingError.calendarAccessDenied
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = workout.title
        event.startDate = workout.scheduledDate
        event.endDate = workout.scheduledDate.addingTimeInterval(3600) // 1 hour default
        event.location = workout.location
        event.notes = workout.notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add alarm 30 minutes before
        let alarm = EKAlarm(relativeOffset: -1800) // 30 minutes
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            
            // Save event identifier to user defaults
            UserDefaults.standard.set(event.eventIdentifier, forKey: "calendar_\(workout.id)")
        } catch {
            throw GroupWorkoutSchedulingError.calendarSaveFailed
        }
    }
    
    func removeFromCalendar(_ workout: GroupWorkout) async throws {
        let status = await requestCalendarAccess()
        guard status == .fullAccess else {
            throw GroupWorkoutSchedulingError.calendarAccessDenied
        }
        
        guard let eventId = UserDefaults.standard.string(forKey: "calendar_\(workout.id)"),
              let event = eventStore.event(withIdentifier: eventId) else {
            return // Event not found, consider it removed
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
            UserDefaults.standard.removeObject(forKey: "calendar_\(workout.id)")
        } catch {
            throw GroupWorkoutSchedulingError.calendarRemoveFailed
        }
    }
    
    // MARK: - Private Helpers
    
    private func requestCalendarAccess() async -> EKAuthorizationStatus {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                Task {
                    do {
                        let granted = try await eventStore.requestFullAccessToEvents()
                        continuation.resume(returning: granted ? .fullAccess : .denied)
                    } catch {
                        continuation.resume(returning: .denied)
                    }
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted ? .authorized : .denied)
                }
            }
        }
    }
    
    private func setupSubscriptions() async {
        // Subscribe to group workout updates
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "GroupWorkouts",
            predicate: predicate,
            subscriptionID: "GroupWorkoutUpdates",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        do {
            let savedSubscription = try await cloudKitManager.database.save(subscription)
            subscriptions.append(savedSubscription)
        } catch {
            print("Failed to setup group workout subscription: \(error)")
        }
    }
    
    private func sendJoinNotification(workoutId: String, status: ParticipantStatus) async {
        // Implementation for sending join notifications
    }
    
    private func sendInviteNotification(to userId: String, workoutId: String) async {
        // Implementation for sending invite notifications
    }
    
    private func notifyParticipantsOfUpdate(_ workout: GroupWorkout) async {
        // Implementation for notifying participants of updates
    }
}

// MARK: - Errors

enum GroupWorkoutSchedulingError: LocalizedError {
    case invalidData
    case notFound
    case unauthorized
    case inviteNotFound
    case calendarAccessDenied
    case calendarSaveFailed
    case calendarRemoveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid workout data"
        case .notFound:
            return "Workout not found"
        case .unauthorized:
            return "You don't have permission to perform this action"
        case .inviteNotFound:
            return "Invite not found or expired"
        case .calendarAccessDenied:
            return "Calendar access denied. Please enable in Settings."
        case .calendarSaveFailed:
            return "Failed to save to calendar"
        case .calendarRemoveFailed:
            return "Failed to remove from calendar"
        }
    }
}