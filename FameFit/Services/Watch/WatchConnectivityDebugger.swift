//
//  WatchConnectivityDebugger.swift
//  FameFit
//
//  Debug logger for WatchConnectivity messages in TestFlight
//

import Foundation
import WatchConnectivity
#if os(iOS)
import UIKit
#else
import WatchKit
#endif

/// Debug logger for WatchConnectivity - stores recent messages for debugging
@MainActor
final class WatchConnectivityDebugger: ObservableObject {
    static let shared = WatchConnectivityDebugger()
    
    @Published var connectionStatus = ConnectionStatus()
    @Published var recentMessages: [DebugMessage] = []
    @Published var lastSyncDate: Date?
    @Published var pendingTransfers = 0
    
    private let maxMessages = 20
    
    struct ConnectionStatus {
        var isPaired = false
        var isWatchAppInstalled = false
        var isReachable = false
        var hasContentPending = false
        var activationState = "Not Activated"
        
        mutating func update(from session: WCSession) {
            #if os(iOS)
            // On iOS, we can check pairing and installation status
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
            #else
            // On watchOS, these properties don't exist
            // Set them based on session state instead
            isPaired = session.activationState == .activated
            isWatchAppInstalled = true // Watch app is obviously installed
            #endif
            isReachable = session.isReachable
            hasContentPending = session.hasContentPending
            
            switch session.activationState {
            case .notActivated:
                activationState = "Not Activated"
            case .inactive:
                activationState = "Inactive"
            case .activated:
                activationState = "Activated"
            @unknown default:
                activationState = "Unknown"
            }
        }
    }
    
    struct DebugMessage: Identifiable {
        let id = UUID()
        let timestamp: Date
        let direction: Direction
        let deliveryMethod: DeliveryMethod
        let messageType: String
        let summary: String
        let fullMessage: [String: Any]
        
        enum Direction: String {
            case sent = "→"
            case received = "←"
        }
        
        enum DeliveryMethod: String {
            case sendMessage = "Direct"
            case transferUserInfo = "Queued"
            case applicationContext = "Context"
            case mixed = "Multi"
        }
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return formatter.string(from: timestamp)
        }
    }
    
    private init() {
        updateConnectionStatus()
    }
    
    // MARK: - Logging Methods
    
    func logSent(_ message: [String: Any], method: DebugMessage.DeliveryMethod) {
        let messageType = message["type"] as? String ?? "unknown"
        let summary = createSummary(for: message)
        
        let debugMessage = DebugMessage(
            timestamp: Date(),
            direction: .sent,
            deliveryMethod: method,
            messageType: messageType,
            summary: summary,
            fullMessage: message
        )
        
        addMessage(debugMessage)
        FameFitLogger.debug("📤 Sent \(messageType) via \(method.rawValue)", category: FameFitLogger.connectivity)
    }
    
    func logReceived(_ message: [String: Any], method: DebugMessage.DeliveryMethod) {
        let messageType = message["type"] as? String ?? "unknown"
        let summary = createSummary(for: message)
        
        let debugMessage = DebugMessage(
            timestamp: Date(),
            direction: .received,
            deliveryMethod: method,
            messageType: messageType,
            summary: summary,
            fullMessage: message
        )
        
        addMessage(debugMessage)
        lastSyncDate = Date()
        FameFitLogger.debug("📥 Received \(messageType) via \(method.rawValue)", category: FameFitLogger.connectivity)
    }
    
    private func addMessage(_ message: DebugMessage) {
        recentMessages.append(message)
        if recentMessages.count > maxMessages {
            recentMessages.removeFirst()
        }
    }
    
    private func createSummary(for message: [String: Any]) -> String {
        if let type = message["type"] as? String {
            switch type {
            case "workoutCompleted":
                if let workoutID = message["workoutID"] as? String {
                    return "Workout: \(workoutID.prefix(8))..."
                }
            case "groupWorkoutState":
                if let hasActive = message["hasActiveWorkout"] as? Bool {
                    return hasActive ? "Group workout available" : "No active workout"
                }
            case "userProfile":
                if let username = message["username"] as? String {
                    return "Profile: \(username)"
                }
            case "workoutMetrics":
                if let hr = message["heartRate"] as? Double {
                    return "HR: \(Int(hr)) bpm"
                }
            case "syncRequest":
                return "Requesting sync"
            case "connectivityTest":
                return message["message"] as? String ?? "Test message"
            default:
                break
            }
        }
        return "Message"
    }
    
    // MARK: - Connection Status
    
    func updateConnectionStatus() {
        let session = WCSession.default
        connectionStatus.update(from: session)
        
        #if os(iOS)
        pendingTransfers = session.outstandingUserInfoTransfers.count
        #else
        pendingTransfers = WCSession.default.outstandingUserInfoTransfers.count
        #endif
    }
    
    // MARK: - Test Actions
    
    func sendTestMessage() {
        #if os(iOS)
        let deviceName = "iPhone"
        let deviceID = UIDevice.current.name
        #else
        let deviceName = "Apple Watch"
        let deviceID = WKInterfaceDevice.current().name
        #endif
        
        // Build details dictionary separately to handle platform differences
        var details: [String: Any] = [
            "reachable": WCSession.default.isReachable,
            "pending": WCSession.default.hasContentPending
        ]
        
        #if os(iOS)
        // On iOS, we can check if paired
        details["paired"] = WCSession.default.isPaired
        details["watchAppInstalled"] = WCSession.default.isWatchAppInstalled
        #else
        // On watchOS, isPaired property doesn't exist
        // The Watch app running means iOS app exists somewhere
        details["phoneAppExists"] = true
        #endif
        
        let testMessage: [String: Any] = [
            "id": UUID().uuidString,
            "type": "connectivityTest",
            "timestamp": Date(),
            "device": deviceName,
            "message": "Test from \(deviceID) at \(Date().formatted(date: .omitted, time: .shortened))",
            "details": details
        ]
        
        // Send using multiple methods to test
        WCSession.default.transferUserInfo(testMessage)
        logSent(testMessage, method: .transferUserInfo)
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(testMessage) { response in
                FameFitLogger.info("Test message acknowledged: \(response)", category: FameFitLogger.connectivity)
            } errorHandler: { error in
                FameFitLogger.error("Test message failed", error: error, category: FameFitLogger.connectivity)
            }
            logSent(testMessage, method: .sendMessage)
        }
    }
    
    func clearMessages() {
        recentMessages.removeAll()
    }
}