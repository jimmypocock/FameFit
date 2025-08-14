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
#if os(iOS)
import UIKit
#endif

/// Enhanced manager for Watch-Phone communication with testing support
public final class EnhancedWatchConnectivityManager: NSObject, ObservableObject, WatchConnectivityProtocol {
    
    // MARK: - Published Properties
    
    @Published public private(set) var connectionState: ConnectionState = .notPaired
    @Published public private(set) var lastReceivedMessage: [String: Any] = [:]
    @Published public private(set) var pendingGroupWorkout: GroupWorkoutCommand?
    @Published public private(set) var lastWorkoutCompletion: WorkoutCompletionInfo?
    
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
    
    public struct WorkoutCompletionInfo: Codable {
        public let workoutID: String
        public let timestamp: Date
        public let metrics: WorkoutMetrics?
        public let groupWorkoutID: String?
        
        public struct WorkoutMetrics: Codable {
            public let heartRate: Double
            public let activeEnergy: Double
            public let distance: Double
            public let elapsedTime: TimeInterval
        }
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
    
    // MARK: - WatchConnectivityProtocol Conformance
    
    public var isReachable: Bool {
        connectionState == .reachable
    }
    
    public var connectivityStatePublisher: AnyPublisher<WatchConnectivityState, Never> {
        $connectionState
            .map { state in
                let activationState: WCSessionActivationState
                switch state {
                case .reachable:
                    activationState = .activated
                case .paired, .unreachable:
                    activationState = .activated
                case .notPaired:
                    activationState = .inactive
                case .simulatorMode:
                    activationState = .activated
                }
                
                return WatchConnectivityState(
                    isReachable: state == .reachable,
                    isPaired: state == .paired || state == .reachable,
                    isWatchAppInstalled: state != .notPaired,
                    activationState: activationState
                )
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            
            FameFitLogger.info("⌚📱 WatchConnectivity session setup", category: FameFitLogger.connectivity)
        } else {
            FameFitLogger.warning("⌚📱 WatchConnectivity not supported", category: FameFitLogger.connectivity)
        }
        
        // Handle simulator mode
        if isSimulator {
            handleSimulatorMode()
        }
    }
    
    // MARK: - WatchConnectivityProtocol Methods
    
    public func activate() async {
        // Session is already activated in init, but we can check state
        if session?.activationState != .activated {
            session?.activate()
        }
    }
    
    public func startWorkout(type: Int) async throws {
        let message: [String: Any] = [
            "command": "startWorkout",
            "workoutType": type,
            "timestamp": Date()
        ]
        try await sendMessageInternal(message)
    }
    
    public func syncData(_ data: [String: Any]) async throws {
        var syncMessage = data
        syncMessage["command"] = "syncData"
        syncMessage["timestamp"] = Date()
        try await sendMessageInternal(syncMessage)
    }
    
    public func sendMessage(_ message: [String: Any]) async throws -> [String: Any] {
        if message["requiresReply"] as? Bool == true {
            return try await sendMessageWithReply(message)
        } else {
            try await sendMessageInternal(message)
            return [:]
        }
    }
    
    public func transferUserInfo(_ userInfo: [String: Any]) async {
        guard let session = session else { return }
        session.transferUserInfo(userInfo)
    }
    
    public func transferFile(_ file: URL, metadata: [String: Any]?) async throws {
        guard let session = session else {
            throw WatchConnectivityError.sessionNotAvailable
        }
        session.transferFile(file, metadata: metadata)
    }
    
    // Legacy compatibility method from protocol
    public func sendGroupWorkoutCommand(workoutID: String, workoutName: String, workoutType: Int, isHost: Bool) {
        Task {
            try? await sendGroupWorkoutCommandAsync(
                workoutID: workoutID,
                workoutName: workoutName,
                workoutType: workoutType,
                isHost: isHost
            )
        }
    }
    
    public func sendUserData(username: String, totalXP: Int) {
        Task {
            let message: [String: Any] = [
                "command": "userData",
                "username": username,
                "totalXP": totalXP
            ]
            try? await sendMessageInternal(message)
        }
    }
    
    public func checkConnection(completion: @escaping (Bool) -> Void) {
        Task {
            let isAvailable = await checkWatchAvailability()
            completion(isAvailable)
        }
    }
    
    public func forceRefreshSessionState() {
        // Trigger a ping to refresh state
        Task {
            _ = await sendPing()
        }
    }
    
    // MARK: - Public Methods
    
    /// Send group workout command to Watch (async version)
    public func sendGroupWorkoutCommandAsync(
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
            try await sendMessageInternal(message)
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
    
    /// Sync user profile to Watch
    func syncUserProfile(_ profile: UserProfile) {
        guard let session = session else {
            FameFitLogger.warning("📱⌚ Cannot sync profile - WCSession not available", category: FameFitLogger.connectivity)
            return
        }
        
        #if os(iOS)
        // Check if Watch app is installed
        guard session.isWatchAppInstalled else {
            FameFitLogger.debug("📱⌚ Watch app not installed - skipping profile sync", category: FameFitLogger.connectivity)
            return
        }
        #endif
        
        // Check if session is activated before trying to update context
        guard session.activationState == .activated else {
            FameFitLogger.warning("📱⌚ Cannot sync profile - WCSession not activated yet", category: FameFitLogger.connectivity)
            // Queue the profile sync for when session activates
            Task {
                // Wait a moment for activation
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if session.activationState == .activated {
                    syncUserProfile(profile) // Retry
                }
            }
            return
        }
        
        // Encode the profile
        guard let profileData = try? JSONEncoder().encode(profile) else {
            FameFitLogger.error("📱⌚ Failed to encode user profile", category: FameFitLogger.connectivity)
            return
        }
        
        let context: [String: Any] = [
            "command": "syncUserProfile",
            "userProfile": profileData,
            "username": profile.username,  // Also send as separate fields for compatibility
            "totalXP": profile.totalXP,
            "timestamp": Date()
        ]
        
        // Update application context (persistent, survives app restarts)
        do {
            try session.updateApplicationContext(context)
            FameFitLogger.info("📱⌚ User profile synced to Watch via application context", category: FameFitLogger.connectivity)
        } catch {
            FameFitLogger.error("📱⌚ Failed to update application context: \(error)", category: FameFitLogger.connectivity)
            
            // Try sending as a message if Watch is reachable
            if session.isReachable {
                session.sendMessage(context, replyHandler: nil) { error in
                    FameFitLogger.error("📱⌚ Failed to send profile message: \(error)", category: FameFitLogger.connectivity)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func sendMessageInternal(_ message: [String: Any]) async throws {
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
        FameFitLogger.info("⌚📱 Message queued for later delivery", category: FameFitLogger.connectivity)
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
        FameFitLogger.info("⌚📱 Running in simulator mode - using alternative sync", category: FameFitLogger.connectivity)
        
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
            
            FameFitLogger.info("⌚📱 Simulator: Received command via UserDefaults", category: FameFitLogger.connectivity)
        }
    }
    
    private func sendViaAlternativeMethod(_ message: [String: Any]) async throws {
        // For simulator testing - use UserDefaults or CloudKit
        if let data = try? JSONSerialization.data(withJSONObject: message) {
            UserDefaults.standard.set(data, forKey: "pending_phone_command")
            FameFitLogger.info("⌚📱 Simulator: Sent command via UserDefaults", category: FameFitLogger.connectivity)
        }
    }
}

// MARK: - WCSessionDelegate

extension EnhancedWatchConnectivityManager: WCSessionDelegate {
    
    nonisolated public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            FameFitLogger.error("WCSession activation failed", error: error, category: FameFitLogger.connectivity)
            return
        }
        
        Task { @MainActor in
            self.updateConnectionState(session)
            
            // Process any queued messages
            self.processMessageQueue()
        }
        
        FameFitLogger.info("⌚📱 WCSession activated: \(activationState.rawValue)", category: FameFitLogger.connectivity)
    }
    
    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        FameFitLogger.info("⌚📱 WCSession became inactive", category: FameFitLogger.connectivity)
    }
    
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        FameFitLogger.info("⌚📱 WCSession deactivated", category: FameFitLogger.connectivity)
        // Reactivate
        session.activate()
    }
    
    nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.updateConnectionState(session)
        }
    }
    #endif
    
    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateConnectionState(session)
            
            // Try to process queued messages
            if session.isReachable {
                self.processMessageQueue()
            }
        }
    }
    
    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.lastReceivedMessage = message
            self.handleReceivedMessage(message)
        }
    }
    
    nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
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
    
    private func handleProfileRequest() -> [String: Any] {
        FameFitLogger.info("📱⌚ Handling profile request from Watch", category: FameFitLogger.connectivity)
        
        #if os(iOS)
        // Try to get the current profile and sync it
        Task { @MainActor in
            // Get the profile from the dependency container
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let profileService = appDelegate.dependencyContainer?.userProfileService as? UserProfileService {
                
                // First try to use cached profile
                if let currentProfile = profileService.currentProfile {
                    // Sync the profile immediately
                    self.syncUserProfile(currentProfile)
                    FameFitLogger.info("📱⌚ Profile synced in response to Watch request (from cache)", category: FameFitLogger.connectivity)
                    
                    // Profile is already synced via syncUserProfile above
                } else {
                    // No cached profile, fetch fresh
                    Task {
                        do {
                            let profile = try await profileService.fetchCurrentUserProfile()
                            self.syncUserProfile(profile)
                            FameFitLogger.info("📱⌚ Fresh profile fetched and synced to Watch", category: FameFitLogger.connectivity)
                        } catch {
                            FameFitLogger.error("📱⌚ Failed to fetch profile for Watch", error: error, category: FameFitLogger.connectivity)
                        }
                    }
                }
            } else {
                FameFitLogger.warning("📱⌚ No dependency container available for profile sync", category: FameFitLogger.connectivity)
            }
        }
        #endif
        
        return ["status": "profile sync initiated"]
    }
    
    private func handleWorkoutCompleted(_ message: [String: Any]) -> [String: Any] {
        FameFitLogger.info("📱⌚ Received workout completion from Watch", category: FameFitLogger.connectivity)
        
        guard let workoutID = message["workoutID"] as? String else {
            return ["status": "error", "message": "Missing workout ID"]
        }
        
        // Parse metrics if available
        var metrics: WorkoutCompletionInfo.WorkoutMetrics?
        if let metricsDict = message["metrics"] as? [String: Any] {
            metrics = WorkoutCompletionInfo.WorkoutMetrics(
                heartRate: metricsDict["heartRate"] as? Double ?? 0,
                activeEnergy: metricsDict["activeEnergy"] as? Double ?? 0,
                distance: metricsDict["distance"] as? Double ?? 0,
                elapsedTime: metricsDict["elapsedTime"] as? TimeInterval ?? 0
            )
        }
        
        // Create completion info
        let completionInfo = WorkoutCompletionInfo(
            workoutID: workoutID,
            timestamp: message["timestamp"] as? Date ?? Date(),
            metrics: metrics,
            groupWorkoutID: message["groupWorkoutID"] as? String
        )
        
        // Update published property
        lastWorkoutCompletion = completionInfo
        
        // Trigger immediate HealthKit sync
        NotificationCenter.default.post(
            name: Notification.Name("WatchWorkoutCompleted"),
            object: nil,
            userInfo: ["workoutID": workoutID]
        )
        
        FameFitLogger.info("✅ Workout completion processed: \(workoutID)", category: FameFitLogger.connectivity)
        
        // Return acknowledgment with any additional data (like XP earned)
        return [
            "status": "received",
            "workoutID": workoutID,
            "message": "Workout received and queued for sync"
        ]
    }
    
    @discardableResult
    private func handleReceivedMessage(_ message: [String: Any]) -> [String: Any] {
        guard let command = message["command"] as? String else {
            return ["status": "error", "message": "No command specified"]
        }
        
        switch command {
        case "ping":
            return ["status": "pong"]
            
        case "requestUserProfile":
            // Watch is requesting the user profile
            FameFitLogger.info("📱⌚ Watch requested user profile", category: FameFitLogger.connectivity)
            return handleProfileRequest()
            
        case "requestWorkoutSync":
            // Watch is requesting recent workouts
            FameFitLogger.info("📱⌚ Watch requested workout sync", category: FameFitLogger.connectivity)
            
            #if os(iOS)
            // Trigger workout sync
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
               let syncManager = appDelegate.dependencyContainer?.workoutSyncManager {
                Task {
                    await syncManager.performManualSync()
                    FameFitLogger.info("📱⌚ Triggered manual workout sync for Watch", category: FameFitLogger.connectivity)
                }
            }
            #endif
            
            return ["status": "sync initiated"]
            
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
            
        case "workoutCompleted":
            // Handle workout completion from Watch
            return handleWorkoutCompleted(message)
            
        default:
            FameFitLogger.warning("Unknown command: \(command)", category: FameFitLogger.connectivity)
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

