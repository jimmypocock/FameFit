//
//  EnhancedWatchConnectivityManager.swift
//  FameFit
//
//  Enhanced WatchConnectivity manager with testing support
//  Handles both real device and simulator scenarios
//

import Foundation
import WatchConnectivity
import Combine

/// Enhanced manager for Watch-Phone communication with testing support
@MainActor
public final class EnhancedWatchConnectivityManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = EnhancedWatchConnectivityManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var connectionState: ConnectionState = .notPaired
    @Published public private(set) var lastReceivedMessage: [String: Any] = [:]
    @Published public private(set) var pendingGroupWorkout: GroupWorkoutCommand?
    
    #if os(iOS)
    @Published public private(set) var isPaired = false
    @Published public private(set) var isWatchAppInstalled = false
    #endif
    
    // MARK: - Types
    
    public enum ConnectionState {
        case notPaired
        case paired
        case reachable
        case unreachable
        case simulatorMode // Special state for testing
    }
    
    public struct GroupWorkoutCommand: Codable {
        public let command: String
        public let workoutID: String
        public let workoutName: String
        public let workoutType: Int
        public let isHost: Bool
        public let timestamp: Date
    }
    
    // MARK: - Private Properties
    
    private var session: WCSession?
    private var messageQueue: [MessageQueueItem] = []
    private var isProcessingQueue = false
    
    // Testing support
    private let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()
    
    private struct MessageQueueItem {
        let message: [String: Any]
        let replyHandler: (([String: Any]) -> Void)?
        let errorHandler: ((Error) -> Void)?
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            
            FameFitLogger.info("⌚📱 WatchConnectivity session setup", category: .connectivity)
        } else {
            FameFitLogger.warning("⌚📱 WatchConnectivity not supported", category: .connectivity)
        }
        
        // Handle simulator mode
        if isSimulator {
            handleSimulatorMode()
        }
    }
    
    // MARK: - Public Methods
    
    /// Send group workout command to Watch
    public func sendGroupWorkoutCommand(
        workoutID: String,
        workoutName: String,
        workoutType: Int,
        isHost: Bool
    ) async throws {
        let command = GroupWorkoutCommand(
            command: "startGroupWorkout",
            workoutID: workoutID,
            workoutName: workoutName,
            workoutType: workoutType,
            isHost: isHost,
            timestamp: Date()
        )
        
        let message: [String: Any] = [
            "command": command.command,
            "workoutID": command.workoutID,
            "workoutName": command.workoutName,
            "workoutType": command.workoutType,
            "isHost": command.isHost,
            "timestamp": command.timestamp
        ]
        
        if isSimulator {
            // In simulator, use alternative communication
            try await sendViaAlternativeMethod(message)
        } else {
            // Real device - use WatchConnectivity
            try await sendMessage(message)
        }
    }
    
    /// Check if Watch is available
    public func checkWatchAvailability() async -> Bool {
        if isSimulator {
            // In simulator, always return true for testing
            return true
        }
        
        guard let session = session else { return false }
        
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled && session.isReachable
        #else
        return session.isReachable
        #endif
    }
    
    /// Send test ping to verify connection
    public func sendPing() async -> Bool {
        do {
            let response = try await sendMessageWithReply(["command": "ping"])
            return response["status"] as? String == "pong"
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func sendMessage(_ message: [String: Any]) async throws {
        guard let session = session else {
            throw WatchConnectivityError.sessionNotAvailable
        }
        
        if isSimulator {
            // Use alternative method for simulator
            try await sendViaAlternativeMethod(message)
            return
        }
        
        guard session.isReachable else {
            // Queue message for later
            queueMessage(message)
            throw WatchConnectivityError.watchNotReachable
        }
        
        // Send immediately
        try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(message, replyHandler: { _ in
                continuation.resume()
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    private func sendMessageWithReply(_ message: [String: Any]) async throws -> [String: Any] {
        guard let session = session else {
            throw WatchConnectivityError.sessionNotAvailable
        }
        
        if isSimulator {
            // Simulate response in testing mode
            return ["status": "pong", "testing": true]
        }
        
        guard session.isReachable else {
            throw WatchConnectivityError.watchNotReachable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(message, replyHandler: { response in
                continuation.resume(returning: response)
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    private func queueMessage(_ message: [String: Any]) {
        let item = MessageQueueItem(
            message: message,
            replyHandler: nil,
            errorHandler: nil
        )
        messageQueue.append(item)
        FameFitLogger.info("⌚📱 Message queued for later delivery", category: .connectivity)
    }
    
    private func processMessageQueue() {
        guard !isProcessingQueue,
              !messageQueue.isEmpty,
              let session = session,
              session.isReachable else { return }
        
        isProcessingQueue = true
        
        while !messageQueue.isEmpty && session.isReachable {
            let item = messageQueue.removeFirst()
            session.sendMessage(item.message, replyHandler: item.replyHandler, errorHandler: item.errorHandler)
        }
        
        isProcessingQueue = false
    }
    
    // MARK: - Simulator/Testing Support
    
    private func handleSimulatorMode() {
        connectionState = .simulatorMode
        FameFitLogger.info("⌚📱 Running in simulator mode - using alternative sync", category: .connectivity)
        
        // Set up alternative communication for testing
        setupAlternativeCommunication()
    }
    
    private func setupAlternativeCommunication() {
        // Use CloudKit or UserDefaults for simulator testing
        // This allows testing the flow without real WatchConnectivity
        
        // Monitor UserDefaults for commands (simulator workaround)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkForSimulatorCommands()
            }
        }
    }
    
    private func checkForSimulatorCommands() {
        // Check for commands via shared UserDefaults or CloudKit
        if let commandData = UserDefaults.standard.data(forKey: "pending_watch_command"),
           let command = try? JSONDecoder().decode(GroupWorkoutCommand.self, from: commandData) {
            
            // Process command
            pendingGroupWorkout = command
            
            // Clear after processing
            UserDefaults.standard.removeObject(forKey: "pending_watch_command")
            
            FameFitLogger.info("⌚📱 Simulator: Received command via UserDefaults", category: .connectivity)
        }
    }
    
    private func sendViaAlternativeMethod(_ message: [String: Any]) async throws {
        // For simulator testing - use UserDefaults or CloudKit
        if let data = try? JSONSerialization.data(withJSONObject: message) {
            UserDefaults.standard.set(data, forKey: "pending_phone_command")
            FameFitLogger.info("⌚📱 Simulator: Sent command via UserDefaults", category: .connectivity)
        }
    }
}

// MARK: - WCSessionDelegate

extension EnhancedWatchConnectivityManager: WCSessionDelegate {
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            FameFitLogger.error("WCSession activation failed", error: error, category: .connectivity)
            return
        }
        
        Task { @MainActor in
            self.updateConnectionState(session)
            
            // Process any queued messages
            self.processMessageQueue()
        }
        
        FameFitLogger.info("⌚📱 WCSession activated: \(activationState.rawValue)", category: .connectivity)
    }
    
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        FameFitLogger.info("⌚📱 WCSession became inactive", category: .connectivity)
    }
    
    public func sessionDidDeactivate(_ session: WCSession) {
        FameFitLogger.info("⌚📱 WCSession deactivated", category: .connectivity)
        // Reactivate
        session.activate()
    }
    
    public func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.updateConnectionState(session)
        }
    }
    #endif
    
    public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateConnectionState(session)
            
            // Try to process queued messages
            if session.isReachable {
                self.processMessageQueue()
            }
        }
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.lastReceivedMessage = message
            self.handleReceivedMessage(message)
        }
    }
    
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.lastReceivedMessage = message
            let response = self.handleReceivedMessage(message)
            replyHandler(response)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateConnectionState(_ session: WCSession) {
        if isSimulator {
            connectionState = .simulatorMode
            return
        }
        
        #if os(iOS)
        if !session.isPaired {
            connectionState = .notPaired
        } else if !session.isWatchAppInstalled {
            connectionState = .paired
        } else if session.isReachable {
            connectionState = .reachable
        } else {
            connectionState = .unreachable
        }
        #else
        connectionState = session.isReachable ? .reachable : .unreachable
        #endif
    }
    
    @discardableResult
    private func handleReceivedMessage(_ message: [String: Any]) -> [String: Any] {
        guard let command = message["command"] as? String else {
            return ["status": "error", "message": "No command specified"]
        }
        
        switch command {
        case "ping":
            return ["status": "pong"]
            
        case "startGroupWorkout":
            if let workoutID = message["workoutID"] as? String,
               let workoutName = message["workoutName"] as? String,
               let workoutType = message["workoutType"] as? Int,
               let isHost = message["isHost"] as? Bool {
                
                let command = GroupWorkoutCommand(
                    command: "startGroupWorkout",
                    workoutID: workoutID,
                    workoutName: workoutName,
                    workoutType: workoutType,
                    isHost: isHost,
                    timestamp: Date()
                )
                pendingGroupWorkout = command
                
                return ["status": "received"]
            }
            
        case "workoutStarted":
            // Watch confirmed workout started
            return ["status": "acknowledged"]
            
        case "workoutMetrics":
            // Handle incoming metrics from Watch
            return ["status": "received"]
            
        default:
            FameFitLogger.warning("Unknown command: \(command)", category: .connectivity)
        }
        
        return ["status": "unknown"]
    }
}

// MARK: - Error Types

public enum WatchConnectivityError: LocalizedError {
    case sessionNotAvailable
    case watchNotReachable
    case messageFailed
    
    public var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            return "WatchConnectivity session not available"
        case .watchNotReachable:
            return "Apple Watch is not reachable"
        case .messageFailed:
            return "Failed to send message to Watch"
        }
    }
}

// MARK: - Logger Extension

extension FameFitLogger.Category {
    static let connectivity = FameFitLogger.Category("connectivity")
}