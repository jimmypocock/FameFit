//
//  WatchConnectivityManager.swift
//  FameFit
//
//  Manages communication between iPhone and Apple Watch
//

import Foundation
import WatchConnectivity

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
        handleMessage(message)
        replyHandler(["status": "received"])
    }
    
    private func handleMessage(_ message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        
        switch command {
        case "workoutStarted":
            print("Workout started on watch")
            // Handle workout started notification
            
        case "workoutEnded":
            print("Workout ended on watch")
            // Handle workout ended notification
            
        case "ping":
            print("Received ping from watch")
            
        default:
            print("Unknown command: \(command)")
        }
    }
}
