//
//  WatchConnectivityManager.swift
//  FameFit Watch App
//
//  Handles communication from iPhone
//

#if os(watchOS)
import Foundation
import WatchConnectivity
import SwiftUI
import UserNotifications

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var receivedWorkoutType: Int?
    @Published var shouldStartWorkout = false
    @Published var lastReceivedUserData: [String: Any]?
    
    override private init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        
        // Request notification permissions
        requestNotificationPermissions()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("⌚ Notification permissions granted")
            } else if let error = error {
                print("⌚ Notification permission error: \(error)")
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
            return
        }
        print("WCSession activated on watch")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessage(message)
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("⌚ Received application context: \(applicationContext)")
        handleMessage(applicationContext)
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("WCSession reachability changed: \(session.isReachable)")
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        print("⌚ Received application context: \(applicationContext)")
        
        guard let command = applicationContext["command"] as? String else { 
            print("⌚ No command in application context")
            return 
        }
        
        switch command {
        case "updateUserData":
            handleUserDataUpdate(applicationContext)
        case "startGroupWorkout":
            handleGroupWorkoutCommand(applicationContext)
        default:
            print("⌚ Unknown command in application context: \(command)")
        }
    }
    
    private func handleMessage(_ message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        
        DispatchQueue.main.async {
            switch command {
            case "startWorkout":
                if let workoutType = message["workoutType"] as? Int {
                    self.receivedWorkoutType = workoutType
                    self.shouldStartWorkout = true
                }
                
            case "startGroupWorkout":
                self.handleGroupWorkoutCommand(message)
                
            case "updateUserData":
                self.handleUserDataUpdate(message)
                
            case "ping":
                // Just respond that we're here
                print("Received ping from iPhone")
                
            default:
                print("Unknown command: \(command)")
            }
        }
    }
    
    private func handleGroupWorkoutCommand(_ message: [String: Any]) {
        print("📱⌚ handleGroupWorkoutCommand called with: \(message)")
        
        guard let workoutID = message["workoutID"] as? String,
              let workoutName = message["workoutName"] as? String,
              let workoutType = message["workoutType"] as? Int,
              let isHost = message["isHost"] as? Bool else {
            print("❌ Invalid group workout message - missing required fields")
            print("Message contents: \(message)")
            return
        }
        
        print("📱⌚ Group workout details - ID: \(workoutID), Name: \(workoutName), Type: \(workoutType), IsHost: \(isHost)")
        
        // Store group workout info
        UserDefaults.standard.set(workoutID, forKey: "pendingGroupWorkoutID")
        UserDefaults.standard.set(workoutName, forKey: "pendingGroupWorkoutName")
        UserDefaults.standard.set(isHost, forKey: "pendingGroupWorkoutIsHost")
        UserDefaults.standard.set(workoutType, forKey: "pendingGroupWorkoutType")
        UserDefaults.standard.synchronize()
        
        // Trigger workout start - ensure this happens on main thread
        DispatchQueue.main.async {
            print("📱⌚ Setting receivedWorkoutType to \(workoutType) and shouldStartWorkout to true")
            self.receivedWorkoutType = workoutType
            self.shouldStartWorkout = true
        }
        
        // Show notification
        showGroupWorkoutNotification(workoutName: workoutName, isHost: isHost)
        
        print("📱⌚ Successfully processed group workout: \(workoutName) (Host: \(isHost))")
    }
    
    private func handleUserDataUpdate(_ message: [String: Any]) {
        // Store user data
        if let username = message["username"] as? String {
            UserDefaults.standard.set(username, forKey: "watch_username")
        }
        
        if let totalXP = message["totalXP"] as? Int {
            UserDefaults.standard.set(totalXP, forKey: "watch_totalXP")
        }
        
        // Store for immediate access
        self.lastReceivedUserData = [
            "username": message["username"] ?? "User",
            "totalXP": message["totalXP"] ?? 0
        ]
        
        print("📱⌚ Updated user data: \(message["username"] ?? "Unknown") - \(message["totalXP"] ?? 0) XP")
    }
    
    private func showGroupWorkoutNotification(workoutName: String, isHost: Bool) {
        let content = UNMutableNotificationContent()
        content.title = "Group Workout Ready!"
        content.body = isHost ? "Start '\(workoutName)' as host" : "Join '\(workoutName)' now"
        content.sound = .default
        content.categoryIdentifier = "GROUP_WORKOUT"
        
        // Add actions
        content.interruptionLevel = .timeSensitive
        
        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "group_workout_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⌚ Failed to show notification: \(error)")
            } else {
                print("⌚ Notification scheduled for group workout: \(workoutName)")
            }
        }
    }
}
#endif
