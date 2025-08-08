//
//  NotificationService.swift
//  FameFit
//
//  Handles local notifications for group workouts and other app events
//

import Foundation
import UserNotifications
import UIKit

class NotificationService {
    static let shared = NotificationService()
    
    private init() {
        setupNotificationCategories()
    }
    
    // MARK: - Setup
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("📱 Notification permissions granted")
                setupNotificationCategories()
            }
            
            return granted
        } catch {
            print("📱 Failed to request notification permissions: \(error)")
            return false
        }
    }
    
    private func setupNotificationCategories() {
        // Group workout category with actions
        let startAction = UNNotificationAction(
            identifier: "START_WORKOUT",
            title: "Start Workout",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        
        let groupWorkoutCategory = UNNotificationCategory(
            identifier: "GROUP_WORKOUT",
            actions: [startAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([groupWorkoutCategory])
    }
    
    // MARK: - Group Workout Notifications
    
    func scheduleGroupWorkoutStartNotification(
        workout: GroupWorkout,
        isHost: Bool,
        minutesBefore: Int = 5
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Group Workout Starting Soon!"
        
        if isHost {
            content.body = "Your group workout '\(workout.name)' starts in \(minutesBefore) minutes. Open FameFit on your Apple Watch to begin."
        } else {
            content.body = "'\(workout.name)' starts in \(minutesBefore) minutes. Open FameFit on your Apple Watch to join."
        }
        
        content.sound = .default
        content.categoryIdentifier = "GROUP_WORKOUT"
        content.userInfo = [
            "workoutID": workout.id,
            "workoutName": workout.name,
            "workoutType": workout.workoutType.rawValue,
            "isHost": isHost
        ]
        
        // Set interruption level for time-sensitive workout notifications
        content.interruptionLevel = .timeSensitive
        
        // Calculate trigger time (5 minutes before start)
        let triggerDate = workout.scheduledStart.addingTimeInterval(-Double(minutesBefore * 60))
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            ),
            repeats: false
        )
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "group_workout_start_\(workout.id)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 Scheduled notification for workout '\(workout.name)' at \(triggerDate)")
        } catch {
            print("📱 Failed to schedule workout notification: \(error)")
        }
    }
    
    func cancelGroupWorkoutNotification(workoutID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["group_workout_start_\(workoutID)"]
        )
        print("📱 Cancelled notification for workout \(workoutID)")
    }
    
    // MARK: - Immediate Notifications
    
    func showGroupWorkoutNowNotification(
        workoutName: String,
        workoutType: Int,
        workoutID: String,
        isHost: Bool
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Group Workout Ready!"
        content.body = isHost ? 
            "Start '\(workoutName)' now on your Apple Watch" : 
            "Join '\(workoutName)' now on your Apple Watch"
        content.sound = .default
        content.categoryIdentifier = "GROUP_WORKOUT"
        content.userInfo = [
            "workoutID": workoutID,
            "workoutName": workoutName,
            "workoutType": workoutType,
            "isHost": isHost
        ]
        content.interruptionLevel = .timeSensitive
        
        // Immediate trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "group_workout_now_\(workoutID)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("📱 Showed immediate notification for workout '\(workoutName)'")
        } catch {
            print("📱 Failed to show immediate notification: \(error)")
        }
    }
}