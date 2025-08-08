//
//  WatchConnectivityManager.swift
//  FameFit
//
//  Manages communication between iPhone and Apple Watch
//

import Foundation
import WatchConnectivity
import UIKit

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
        }
    }
    
    // MARK: - Public Methods
    
    func startWorkout(type: Int) {
        guard WCSession.default.isReachable else {
            print("Watch not reachable")
            return
        }
        
        let message: [String: Any] = [
            "command": "startWorkout",
            "workoutType": type
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            print("Watch acknowledged workout start: \(response)")
        }, errorHandler: { error in
            print("Error starting workout on watch: \(error)")
        })
    }
    
    func sendGroupWorkoutCommand(workoutID: String, workoutName: String, workoutType: Int, isHost: Bool) {
        print("📱 sendGroupWorkoutCommand called - ID: \(workoutID), Name: \(workoutName), Type: \(workoutType), Host: \(isHost)")
        
        // Always try to send via application context first (persistent)
        let context: [String: Any] = [
            "command": "startGroupWorkout",
            "workoutID": workoutID,
            "workoutName": workoutName,
            "workoutType": workoutType,
            "isHost": isHost,
            "timestamp": Date()
        ]
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("📱 Sent group workout via application context")
        } catch {
            print("❌ Failed to update application context: \(error)")
        }
        
        // Also try immediate message if reachable
        if WCSession.default.isReachable {
            print("✅ Watch is reachable, sending immediate message")
        } else {
            print("⚠️ Watch not immediately reachable")
            print("📱 Session state - isPaired: \(WCSession.default.isPaired), isWatchAppInstalled: \(WCSession.default.isWatchAppInstalled), isReachable: \(WCSession.default.isReachable)")
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
        
        print("📱 Sending message to Watch: \(message)")
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            print("✅ Watch acknowledged group workout: \(response)")
        }, errorHandler: { error in
            print("❌ Error sending group workout to watch: \(error)")
            
            // Try application context as fallback
            do {
                try WCSession.default.updateApplicationContext(message)
                print("📱 Sent group workout via application context as fallback after error")
            } catch {
                print("❌ Failed to update application context: \(error)")
            }
        })
    }
    
    func sendUserData(username: String, totalXP: Int) {
        guard WCSession.default.isReachable else {
            print("Watch not reachable for user data update")
            return
        }
        
        let message: [String: Any] = [
            "command": "updateUserData",
            "username": username,
            "totalXP": totalXP,
            "timestamp": Date()
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            print("Watch acknowledged user data update: \(response)")
        }, errorHandler: { error in
            print("Error sending user data to watch: \(error)")
            // Try to send via application context as fallback
            do {
                try WCSession.default.updateApplicationContext(message)
            } catch {
                print("Failed to update application context: \(error)")
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
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
            return
        }
        
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            #if os(iOS)
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            #endif
        }
        
        print("WCSession activated with state: \(activationState.rawValue)")
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
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
                print("Failed to fetch active workouts: \(error)")
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
            print("Workout started on watch")
            // Handle workout started notification
            
        case "workoutEnded":
            print("Workout ended on watch")
            // Handle workout ended notification
            
        case "workoutCompleted":
            if let workoutID = message["workoutID"] as? String {
                handleWorkoutCompleted(workoutID)
            }
            
        case "ping":
            print("Received ping from watch")
            
        default:
            print("Unknown command: \(command)")
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
        
        print("📊 Received metrics from Watch: HR=\(metrics["heartRate"] ?? 0), Energy=\(metrics["activeEnergy"] ?? 0)")
    }
    
    private func handleWorkoutCompleted(_ workoutID: String) {
        print("Workout completed on Watch: \(workoutID)")
        
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
