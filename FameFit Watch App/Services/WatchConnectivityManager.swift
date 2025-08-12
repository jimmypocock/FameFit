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
import os.log

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var receivedWorkoutType: Int?
    @Published var shouldStartWorkout = false
    @Published var lastReceivedUserData: [String: Any]?
    @Published var pendingGroupWorkout: (id: String, name: String, type: Int, isHost: Bool)?
    
    override private init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        
        // Request notification permissions and set up delegate
        requestNotificationPermissions()
        setupNotificationDelegate()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                FameFitLogger.info("⌚ Notification permissions granted", category: FameFitLogger.sync)
            } else if let error = error {
                FameFitLogger.info("⌚ Notification permission error: \(error)", category: FameFitLogger.sync)
            }
        }
    }
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    private var hasPendingCheckScheduled = false
    
    private func forceFetchPendingTransfers() {
        // Prevent multiple pending checks from being scheduled
        guard !hasPendingCheckScheduled else { return }
        
        FameFitLogger.info("⌚ Forcing check for pending transfers", category: FameFitLogger.sync)
        
        // Check for outstanding user info transfers
        let session = WCSession.default
        
        // Log current state
        FameFitLogger.debug("⌚ Outstanding userInfoTransfers: \(session.outstandingUserInfoTransfers.count)", category: FameFitLogger.sync)
        FameFitLogger.debug("⌚ Outstanding fileTransfers: \(session.outstandingFileTransfers.count)", category: FameFitLogger.sync)
        
        // If we have the application context, use it
        if !session.receivedApplicationContext.isEmpty {
            FameFitLogger.info("⌚ Using received application context", category: FameFitLogger.sync)
            handleMessage(session.receivedApplicationContext)
        }
        
        // Schedule ONE check in case transfers arrive later
        hasPendingCheckScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.hasPendingCheckScheduled = false
            
            if session.hasContentPending {
                FameFitLogger.warning("⌚ Still has content pending after 2 seconds", category: FameFitLogger.sync)
                
                // Try to trigger delegate methods by reactivating
                if session.activationState == .activated {
                    FameFitLogger.info("⌚ Attempting to re-trigger pending content delivery", category: FameFitLogger.sync)
                    
                    // Check receivedApplicationContext again
                    if !session.receivedApplicationContext.isEmpty {
                        FameFitLogger.info("⌚ Found application context on retry", category: FameFitLogger.sync)
                        self?.handleMessage(session.receivedApplicationContext)
                    }
                }
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            FameFitLogger.info("⌚❌ WCSession activation failed: \(error)", category: FameFitLogger.sync)
            return
        }
        FameFitLogger.info("⌚✅ WCSession activated - state: \(activationState.rawValue)", category: FameFitLogger.sync)
        // Only log context if it's not empty to reduce noise
        if !session.receivedApplicationContext.isEmpty {
            FameFitLogger.debug("⌚ Session has application context: \(session.receivedApplicationContext)", category: FameFitLogger.sync)
        }
        
        // Check for any pending transfers
        if session.hasContentPending {
            FameFitLogger.info("⌚ Session has content pending - forcing check for pending transfers", category: FameFitLogger.sync)
            
            // Force check for pending user info transfers
            forceFetchPendingTransfers()
        }
        
        // Also check application context even if empty
        if !session.receivedApplicationContext.isEmpty {
            FameFitLogger.info("⌚ Found application context on activation: \(session.receivedApplicationContext)", category: FameFitLogger.sync)
            handleMessage(session.receivedApplicationContext)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessage(message)
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        FameFitLogger.info("⌚ Received application context: \(applicationContext)", category: FameFitLogger.sync)
        
        // Check if it's a user profile update (may not have a command)
        if applicationContext["userProfile"] != nil {
            FameFitLogger.info("⌚ Found user profile in application context", category: FameFitLogger.sync)
            handleUserDataUpdate(applicationContext)
            return
        }
        
        guard let command = applicationContext["command"] as? String else { 
            FameFitLogger.info("⌚ No command in application context", category: FameFitLogger.sync)
            // Still handle it as a generic message in case it has other content
            handleMessage(applicationContext)
            return 
        }
        
        switch command {
        case "updateUserData", "syncUserProfile":
            handleUserDataUpdate(applicationContext)
        case "startGroupWorkout":
            handleGroupWorkoutCommand(applicationContext)
        default:
            FameFitLogger.info("⌚ Unknown command in application context: \(command)", category: FameFitLogger.sync)
            // Handle as generic message
            handleMessage(applicationContext)
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        FameFitLogger.info("WCSession reachability changed: \(session.isReachable)", category: FameFitLogger.sync)
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        FameFitLogger.info("⌚ Received userInfo transfer: \(userInfo)", category: FameFitLogger.sync)
        handleMessage(userInfo)
    }
    
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if let error = error {
            FameFitLogger.info("⌚ UserInfo transfer failed: \(error)", category: FameFitLogger.sync)
        } else {
            FameFitLogger.info("⌚ UserInfo transfer completed successfully", category: FameFitLogger.sync)
        }
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        FameFitLogger.info("⌚ Received file transfer: \(file.fileURL)", category: FameFitLogger.sync)
        
        // Check if it's a group workout file
        if let metadata = file.metadata,
           metadata["type"] as? String == "groupWorkout" {
            
            do {
                let data = try Data(contentsOf: file.fileURL)
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    FameFitLogger.info("⌚ Received group workout via file transfer", category: FameFitLogger.sync)
                    handleMessage(json)
                }
            } catch {
                FameFitLogger.error("⌚ Failed to process file transfer: \(error)", category: FameFitLogger.sync)
            }
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
                FameFitLogger.debug("Received ping from iPhone", category: FameFitLogger.sync)
                
            default:
                FameFitLogger.warning("Unknown command: \(command)", category: FameFitLogger.sync)
            }
        }
    }
    
    func handleGroupWorkoutCommand(_ message: [String: Any]) {
        FameFitLogger.info("📱⌚ handleGroupWorkoutCommand called with: \(message)", category: FameFitLogger.sync)
        
        guard let workoutID = message["workoutID"] as? String,
              let workoutName = message["workoutName"] as? String,
              let workoutType = message["workoutType"] as? Int,
              let isHost = message["isHost"] as? Bool else {
            FameFitLogger.error("❌ Invalid group workout message - missing required fields. Message contents: \(message)", category: FameFitLogger.sync)
            return
        }
        
        FameFitLogger.info("📱⌚ Group workout details - ID: \(workoutID), Name: \(workoutName), Type: \(workoutType), IsHost: \(isHost)", category: FameFitLogger.sync)
        
        // Store group workout info
        UserDefaults.standard.set(workoutID, forKey: "pendingGroupWorkoutID")
        UserDefaults.standard.set(workoutName, forKey: "pendingGroupWorkoutName")
        UserDefaults.standard.set(isHost, forKey: "pendingGroupWorkoutIsHost")
        UserDefaults.standard.set(workoutType, forKey: "pendingGroupWorkoutType")
        UserDefaults.standard.synchronize()
        
        // Trigger workout start - ensure this happens on main thread
        DispatchQueue.main.async {
            FameFitLogger.info("📱⌚ Setting receivedWorkoutType to \(workoutType) and shouldStartWorkout to true", category: FameFitLogger.sync)
            self.receivedWorkoutType = workoutType
            self.shouldStartWorkout = true
        }
        
        // Show notification
        showGroupWorkoutNotification(workoutName: workoutName, isHost: isHost)
        
        FameFitLogger.info("📱⌚ Successfully processed group workout: \(workoutName) (Host: \(isHost))", category: FameFitLogger.sync)
    }
    
    private func handleUserDataUpdate(_ message: [String: Any]) {
        FameFitLogger.info("⌚ Received user profile update from iPhone", category: FameFitLogger.sync)
        
        // Check if we have profile data
        if let profileData = message["userProfile"] as? Data {
            // Decode and update the account service
            if let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                FameFitLogger.info("⌚ Successfully decoded user profile: \(profile.username)", category: FameFitLogger.sync)
                
                // Note: AccountVerificationService will pick up the cached profile on next check
                
                // Cache the profile data for AccountVerificationService to find
                UserDefaults.standard.set(profileData, forKey: AccountCacheKeys.cachedProfileData)
                UserDefaults.standard.set(Date(), forKey: AccountCacheKeys.lastCheckDate)
                
                // Also store individual fields for backward compatibility
                UserDefaults.standard.set(profile.username, forKey: "watch_username")
                UserDefaults.standard.set(profile.totalXP, forKey: "watch_totalXP")
                
                FameFitLogger.info("⌚ Profile cached successfully", category: FameFitLogger.sync)
            }
        } else {
            // Fallback to individual fields for backward compatibility
            if let username = message["username"] as? String {
                UserDefaults.standard.set(username, forKey: "watch_username")
            }
            
            if let totalXP = message["totalXP"] as? Int {
                UserDefaults.standard.set(totalXP, forKey: "watch_totalXP")
            }
        }
        
        // Store for immediate access
        self.lastReceivedUserData = [
            "username": message["username"] ?? "User",
            "totalXP": message["totalXP"] ?? 0
        ]
        
        FameFitLogger.info("📱⌚ Updated user data: \(message["username"] ?? "Unknown") - \(message["totalXP"] ?? 0) XP")
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
                FameFitLogger.info("⌚ Failed to show notification: \(error)", category: FameFitLogger.sync)
            } else {
                FameFitLogger.info("⌚ Notification scheduled for group workout: \(workoutName)", category: FameFitLogger.sync)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension WatchConnectivityManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification, 
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                didReceive response: UNNotificationResponse, 
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        FameFitLogger.info("⌚ Notification tapped: \(response.notification.request.identifier)", category: FameFitLogger.sync)
        
        // Check if this is a group workout notification
        if response.notification.request.identifier.starts(with: "group_workout_") {
            // Check for the pending workout in UserDefaults
            if let workoutID = UserDefaults.standard.string(forKey: "pendingGroupWorkoutID"),
               let workoutName = UserDefaults.standard.string(forKey: "pendingGroupWorkoutName") {
                let isHost = UserDefaults.standard.bool(forKey: "pendingGroupWorkoutIsHost")
                let workoutTypeRaw = UserDefaults.standard.integer(forKey: "pendingGroupWorkoutType")
                
                FameFitLogger.info("⌚ Loading group workout from notification: \(workoutName)", category: FameFitLogger.sync)
                
                // Set the pending workout
                DispatchQueue.main.async {
                    self.pendingGroupWorkout = (id: workoutID, name: workoutName, type: workoutTypeRaw, isHost: isHost)
                    // Trigger workout start
                    self.receivedWorkoutType = workoutTypeRaw
                    self.shouldStartWorkout = true
                }
            }
        }
        
        completionHandler()
    }
}
#endif
