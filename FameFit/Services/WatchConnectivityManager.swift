//
//  WatchConnectivityManager.swift
//  FameFit
//
//  Manages communication between iPhone and Apple Watch
//

import Foundation
import WatchConnectivity
import UIKit
import os.log

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    
    override private init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            
            // Debug output for real device
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.debugSessionState()
            }
        }
    }
    
    private func debugSessionState() {
        FameFitLogger.info("📱 Initial WCSession Debug State:", category: FameFitLogger.sync)
        FameFitLogger.info("  - isSupported: \(WCSession.isSupported())", category: FameFitLogger.sync)
        FameFitLogger.info("  - activationState: \(WCSession.default.activationState.rawValue)", category: FameFitLogger.sync)
        #if os(iOS)
        FameFitLogger.info("  - isPaired: \(WCSession.default.isPaired)", category: FameFitLogger.sync)
        FameFitLogger.info("  - isWatchAppInstalled: \(WCSession.default.isWatchAppInstalled)", category: FameFitLogger.sync)
        FameFitLogger.info("  - isComplicationEnabled: \(WCSession.default.isComplicationEnabled)", category: FameFitLogger.sync)
        #endif
        FameFitLogger.info("  - isReachable: \(WCSession.default.isReachable)", category: FameFitLogger.sync)
    }
    
    // MARK: - Public Methods
    
    func startWorkout(type: Int) {
        guard WCSession.default.isReachable else {
            FameFitLogger.warning("Watch not reachable", category: FameFitLogger.sync)
            return
        }
        
        let message: [String: Any] = [
            "command": "startWorkout",
            "workoutType": type
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            FameFitLogger.info("Watch acknowledged workout start: \(response)", category: FameFitLogger.sync)
        }, errorHandler: { error in
            FameFitLogger.error("Error starting workout on watch: \(error)", category: FameFitLogger.sync)
        })
    }
    
    func sendGroupWorkoutCommand(workoutID: String, workoutName: String, workoutType: Int, isHost: Bool) {
        FameFitLogger.info("📱 sendGroupWorkoutCommand - ID: \(workoutID), Name: \(workoutName), Type: \(workoutType), Host: \(isHost)", category: FameFitLogger.sync)
        
        #if DEBUG
        // Debug WCSession state
        FameFitLogger.debug("📱 WCSession state: isSupported=\(WCSession.isSupported()), activationState=\(WCSession.default.activationState.rawValue), isPaired=\(WCSession.default.isPaired), isWatchAppInstalled=\(WCSession.default.isWatchAppInstalled), isReachable=\(WCSession.default.isReachable), isComplicationEnabled=\(WCSession.default.isComplicationEnabled)", category: FameFitLogger.sync)
        
        // Development warning if Watch app appears not installed
        if WCSession.default.isPaired && !WCSession.default.isWatchAppInstalled {
            FameFitLogger.warning("⚠️ Watch communication unavailable in Xcode builds. Use TestFlight for testing Watch↔iPhone features.", category: FameFitLogger.sync)
            // Note: We still try to send as it sometimes works
        }
        #endif
        
        // Check if Watch is paired
        if !WCSession.default.isPaired {
            FameFitLogger.error("📱 Watch is not paired with this iPhone!", category: FameFitLogger.sync)
            return
        }
        
        // Always try to send via application context first (persistent)
        let context: [String: Any] = [
            "command": "startGroupWorkout",
            "workoutID": workoutID,
            "workoutName": workoutName,
            "workoutType": workoutType,
            "isHost": isHost,
            "timestamp": Date().timeIntervalSince1970  // Use timestamp as number
        ]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            FameFitLogger.info("📱✅ Successfully updated application context", category: FameFitLogger.sync)
            FameFitLogger.debug("📱 Current context: \(WCSession.default.applicationContext)", category: FameFitLogger.sync)
        } catch {
            FameFitLogger.error("❌ Failed to update application context: \(error)", category: FameFitLogger.sync)
        }
        
        // Also send via transferUserInfo (guaranteed delivery)
        let userInfo: [String: Any] = [
            "command": "startGroupWorkout",
            "workoutID": workoutID,
            "workoutName": workoutName,
            "workoutType": workoutType,
            "isHost": isHost,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // ALWAYS send via transferUserInfo - this works even if app "isn't installed"
        let transfer = WCSession.default.transferUserInfo(userInfo)
        FameFitLogger.info("📱 Sent via transferUserInfo - transferring: \(transfer.isTransferring)", category: FameFitLogger.sync)
        
        // Also try sending a file transfer as ultimate fallback
        if let data = try? JSONSerialization.data(withJSONObject: userInfo, options: []) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("workout_\(Date().timeIntervalSince1970).json")
            do {
                try data.write(to: url)
                _ = WCSession.default.transferFile(url, metadata: ["type": "groupWorkout"])
                FameFitLogger.info("📱 Also sent via file transfer as backup", category: FameFitLogger.sync)
            } catch {
                FameFitLogger.error("📱 Failed to create file for transfer: \(error)", category: FameFitLogger.sync)
            }
        }
        
        // Also try immediate message if reachable
        if WCSession.default.isReachable {
            FameFitLogger.info("✅ Watch is reachable, sending immediate message", category: FameFitLogger.sync)
        } else {
            FameFitLogger.warning("⚠️ Watch not immediately reachable, but data sent via context and transferUserInfo", category: FameFitLogger.sync)
            return
        }
        
        let message: [String: Any] = [
            "command": "startGroupWorkout",
            "workoutID": workoutID,
            "workoutName": workoutName,
            "workoutType": workoutType,
            "isHost": isHost,
            "timestamp": Date()
        ]
        
        FameFitLogger.debug("📱 Sending message to Watch: \(message)", category: FameFitLogger.sync)
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            FameFitLogger.info("✅ Watch acknowledged group workout: \(response)", category: FameFitLogger.sync)
        }, errorHandler: { error in
            FameFitLogger.error("❌ Error sending group workout to watch: \(error)", category: FameFitLogger.sync)
            
            // Try application context as fallback
            do {
                try WCSession.default.updateApplicationContext(message)
                FameFitLogger.info("📱 Sent group workout via application context as fallback after error", category: FameFitLogger.sync)
            } catch {
                FameFitLogger.error("❌ Failed to update application context: \(error)", category: FameFitLogger.sync)
            }
        })
    }
    
    func sendUserData(username: String, totalXP: Int) {
        guard WCSession.default.isReachable else {
            FameFitLogger.warning("Watch not reachable for user data update", category: FameFitLogger.sync)
            return
        }
        
        let message: [String: Any] = [
            "command": "updateUserData",
            "username": username,
            "totalXP": totalXP,
            "timestamp": Date()
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            FameFitLogger.info("Watch acknowledged user data update: \(response)", category: FameFitLogger.sync)
        }, errorHandler: { error in
            FameFitLogger.error("Error sending user data to watch: \(error)", category: FameFitLogger.sync)
            // Try to send via application context as fallback
            do {
                try WCSession.default.updateApplicationContext(message)
            } catch {
                FameFitLogger.error("Failed to update application context: \(error)", category: FameFitLogger.sync)
            }
        })
    }
    
    func checkConnection(completion: @escaping (Bool) -> Void) {
        guard WCSession.default.isReachable else {
            completion(false)
            return
        }
        
        WCSession.default.sendMessage(["command": "ping"], replyHandler: { _ in
            completion(true)
        }, errorHandler: { _ in
            completion(false)
        })
    }
    
    func forceRefreshSessionState() {
        FameFitLogger.info("📱 Force refreshing WCSession state...", category: FameFitLogger.sync)
        
        // Deactivate and reactivate the session
        if WCSession.default.activationState == .activated {
            #if os(iOS)
            // On iOS, we can deactivate and reactivate
            WCSession.default.delegate = nil
            WCSession.default.delegate = self
            WCSession.default.activate()
            #endif
        } else {
            // If not activated, just activate
            WCSession.default.activate()
        }
        
        // Update our local state
        DispatchQueue.main.async {
            self.isReachable = WCSession.default.isReachable
            #if os(iOS)
            self.isPaired = WCSession.default.isPaired
            self.isWatchAppInstalled = WCSession.default.isWatchAppInstalled
            
            FameFitLogger.info("📱 After force refresh:", category: FameFitLogger.sync)
            FameFitLogger.info("  - isPaired: \(WCSession.default.isPaired)", category: FameFitLogger.sync)
            FameFitLogger.info("  - isWatchAppInstalled: \(WCSession.default.isWatchAppInstalled)", category: FameFitLogger.sync)
            FameFitLogger.info("  - isReachable: \(WCSession.default.isReachable)", category: FameFitLogger.sync)
            #endif
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            FameFitLogger.error("WCSession activation failed: \(error)", category: FameFitLogger.sync)
            // Try to reactivate after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if WCSession.default.activationState != .activated {
                    FameFitLogger.info("Retrying WCSession activation...", category: FameFitLogger.sync)
                    WCSession.default.activate()
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            #if os(iOS)
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            
            // Log the state for debugging
            FameFitLogger.info("📱 WCSession state after activation:", category: FameFitLogger.sync)
            FameFitLogger.info("  - isPaired: \(session.isPaired)", category: FameFitLogger.sync)
            FameFitLogger.info("  - isWatchAppInstalled: \(session.isWatchAppInstalled)", category: FameFitLogger.sync)
            FameFitLogger.info("  - isReachable: \(session.isReachable)", category: FameFitLogger.sync)
            FameFitLogger.info("  - isComplicationEnabled: \(session.isComplicationEnabled)", category: FameFitLogger.sync)
            
            // If Watch app appears not installed but we know it should be, try re-activating
            if !session.isWatchAppInstalled && session.isPaired {
                FameFitLogger.warning("Watch appears not installed despite being paired. Will retry in 3 seconds...", category: FameFitLogger.sync)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.forceRefreshSessionState()
                }
            }
            #endif
        }
        
        FameFitLogger.info("WCSession activated with state: \(activationState.rawValue)", category: FameFitLogger.sync)
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        FameFitLogger.info("WCSession became inactive", category: FameFitLogger.sync)
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        FameFitLogger.info("WCSession deactivated", category: FameFitLogger.sync)
        // Reactivate the session
        WCSession.default.activate()
    }
    #endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    // MARK: - Message Handling
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // Check if it's a request for active group workout
        if let request = message["request"] as? String, request == "activeGroupWorkout" {
            handleActiveGroupWorkoutRequest(replyHandler: replyHandler)
            return
        }
        
        handleMessage(message)
        replyHandler(["status": "received"])
    }
    
    private func handleActiveGroupWorkoutRequest(replyHandler: @escaping ([String: Any]) -> Void) {
        // Get the dependency container to access group workout service
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let container = appDelegate.dependencyContainer else {
            replyHandler(["error": "No dependency container"])
            return
        }
        
        Task {
            do {
                // Fetch active workouts for the current user
                let activeWorkouts = try await container.groupWorkoutService.fetchActiveWorkouts()
                
                // Find first workout where user is host or participant
                guard let currentUserID = container.cloudKitManager.currentUserID else {
                    await MainActor.run {
                        replyHandler(["error": "No user ID"])
                    }
                    return
                }
                
                // Find workout where user is involved
                let userWorkout = activeWorkouts.first { workout in
                    workout.hostID == currentUserID || 
                    workout.participantIDs.contains(currentUserID)
                }
                
                if let workout = userWorkout {
                    let isHost = workout.hostID == currentUserID
                    
                    let workoutData: [String: Any] = [
                        "id": workout.id,
                        "name": workout.name,
                        "type": Int(workout.workoutType.rawValue),
                        "isHost": isHost
                    ]
                    
                    await MainActor.run {
                        replyHandler(["groupWorkout": workoutData])
                    }
                } else {
                    await MainActor.run {
                        replyHandler(["status": "no_active_workout"])
                    }
                }
            } catch {
                FameFitLogger.error("Failed to fetch active workouts: \(error)", category: FameFitLogger.sync)
                await MainActor.run {
                    replyHandler(["error": "Failed to fetch workouts"])
                }
            }
        }
    }
    
    private func handleMessage(_ message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        
        switch command {
        case "workoutMetrics":
            if let metrics = message["metrics"] as? [String: Any] {
                handleWorkoutMetrics(metrics)
            }
            
        case "workoutStarted":
            FameFitLogger.info("Workout started on watch", category: FameFitLogger.sync)
            // Handle workout started notification
            
        case "workoutEnded":
            FameFitLogger.info("Workout ended on watch", category: FameFitLogger.sync)
            // Handle workout ended notification
            
        case "workoutCompleted":
            if let workoutID = message["workoutID"] as? String {
                handleWorkoutCompleted(workoutID)
            }
            
        case "ping":
            FameFitLogger.debug("Received ping from watch", category: FameFitLogger.sync)
            
        default:
            FameFitLogger.warning("Unknown command: \(command)", category: FameFitLogger.sync)
        }
    }
    
    private func handleWorkoutMetrics(_ metrics: [String: Any]) {
        // Post notification for metrics upload
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("WorkoutMetricsReceived"),
                object: nil,
                userInfo: metrics
            )
        }
        
        FameFitLogger.info("📊 Received metrics from Watch: HR=\(metrics["heartRate"] ?? 0), Energy=\(metrics["activeEnergy"] ?? 0)", category: FameFitLogger.sync)
    }
    
    private func handleWorkoutCompleted(_ workoutID: String) {
        FameFitLogger.info("Workout completed on Watch: \(workoutID)", category: FameFitLogger.sync)
        
        // Post notification for workout completion
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("GroupWorkoutCompletedOnWatch"),
                object: nil,
                userInfo: ["workoutID": workoutID]
            )
        }
    }
}
