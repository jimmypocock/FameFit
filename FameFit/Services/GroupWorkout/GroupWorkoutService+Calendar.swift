//
//  GroupWorkoutService+Calendar.swift
//  FameFit
//
//  Calendar integration for GroupWorkoutService
//

import CloudKit
import EventKit
import Foundation

extension GroupWorkoutService {
    // MARK: - Calendar Integration
    
    func addToCalendar(_ workout: GroupWorkout) async throws {
        FameFitLogger.info("Adding workout to calendar: \(workout.name)", category: FameFitLogger.social)
        
        // Request calendar access if needed
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            throw GroupWorkoutError.calendarAccessDenied
        }
        
        // Create calendar event
        let event = EKEvent(eventStore: eventStore)
        event.title = "🏋️ \(workout.name)"
        event.startDate = workout.scheduledStart
        event.endDate = workout.scheduledEnd
        event.notes = buildEventNotes(for: workout)
        
        if let location = workout.location {
            event.location = location
        }
        
        // Add reminder (15 minutes before)
        let reminder = EKAlarm(relativeOffset: -900) // -15 minutes
        event.addAlarm(reminder)
        
        // Set calendar
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Save event
        do {
            try eventStore.save(event, span: .thisEvent)
            FameFitLogger.info("Successfully added workout to calendar", category: FameFitLogger.social)
            
            // TODO: Store event identifier somewhere for later removal
            FameFitLogger.info("Calendar event created with ID: \(event.eventIdentifier ?? "unknown")", category: FameFitLogger.social)
        } catch {
            FameFitLogger.error("Failed to save calendar event", error: error, category: FameFitLogger.social)
            throw GroupWorkoutError.calendarSaveFailed
        }
    }
    
    func removeFromCalendar(_ workout: GroupWorkout) async throws {
        FameFitLogger.info("Removing workout from calendar: \(workout.name)", category: FameFitLogger.social)
        
        // TODO: Retrieve calendar event ID from storage
        FameFitLogger.debug("Calendar event removal not implemented - need event ID storage", category: FameFitLogger.social)
    }
    
    func syncToCalendar(_ workout: GroupWorkout) async throws {
        FameFitLogger.info("Syncing workout to calendar: \(workout.name)", category: FameFitLogger.social)
        
        // Request calendar access if needed
        let hasAccess = await requestCalendarAccess()
        guard hasAccess else {
            throw GroupWorkoutError.calendarAccessDenied
        }
        
        // TODO: Retrieve calendar event ID from storage
        // For now, always create a new event
        if false {
            // Update existing event
            // This code is unreachable for now
        } else {
            // Create new event
            try await addToCalendar(workout)
        }
    }
    
    // MARK: - Calendar Helpers
    
    func requestCalendarAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                FameFitLogger.error("Failed to request calendar access", error: error, category: FameFitLogger.social)
                return false
            }
        } else {
            // Fallback for iOS 16 and earlier
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func buildEventNotes(for workout: GroupWorkout) -> String {
        var notes = workout.notes ?? ""
        
        if !notes.isEmpty {
            notes += "\n\n"
        }
        
        notes += "FameFit Group Workout\n"
        notes += "Type: \(workout.workoutType)\n"
        notes += "Participants: \(workout.participantCount)/\(workout.maxParticipants)\n"
        
        if workout.joinCode != nil {
            notes += "\nJoin Code: \(workout.joinCode ?? "N/A")"
        }
        
        return notes
    }
}