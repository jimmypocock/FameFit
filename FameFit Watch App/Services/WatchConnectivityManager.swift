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

final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var receivedWorkoutType: Int?
    @Published var shouldStartWorkout = false
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
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
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleMessage(message)
        replyHandler(["status": "received"])
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("WCSession reachability changed: \(session.isReachable)")
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
                
            case "ping":
                // Just respond that we're here
                print("Received ping from iPhone")
                
            default:
                print("Unknown command: \(command)")
            }
        }
    }
}
#endif