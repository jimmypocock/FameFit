//
//  WatchConnectivityManager.swift
//  FameFit
//
//  Async/await implementation of Watch Connectivity
//

import Foundation
import WatchConnectivity
import Combine

// MARK: - Watch Connectivity Implementation

// MARK: - Watch Connectivity Errors

enum WatchConnectivityError: LocalizedError {
    case notSupported
    case notReachable
    case notPaired
    case watchAppNotInstalled
    case sessionNotActivated
    case messageFailed(Error)
    case transferFailed(Error)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Watch Connectivity is not supported on this device"
        case .notReachable:
            return "Apple Watch is not reachable"
        case .notPaired:
            return "Apple Watch is not paired"
        case .watchAppNotInstalled:
            return "FameFit is not installed on Apple Watch"
        case .sessionNotActivated:
            return "Watch Connectivity session is not activated"
        case .messageFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .transferFailed(let error):
            return "Failed to transfer data: \(error.localizedDescription)"
        case .timeout:
            return "Watch communication timed out"
        }
    }
}

// MARK: - Watch Connectivity Singleton

final class WatchConnectivitySingleton: NSObject, ObservableObject, WatchConnectivityProtocol {
    // Singleton instance - required for WatchConnectivity
    static let shared = WatchConnectivitySingleton()
    // Published properties for SwiftUI
    @MainActor @Published private var _isReachable = false
    @MainActor @Published private var _isPaired = false
    @MainActor @Published private var _isWatchAppInstalled = false
    
    // Nonisolated computed properties for protocol conformance
    nonisolated var isReachable: Bool {
        session?.isReachable ?? false
    }
    
    nonisolated var isPaired: Bool {
        #if os(iOS)
        return session?.isPaired ?? false
        #else
        return true
        #endif
    }
    
    nonisolated var isWatchAppInstalled: Bool {
        #if os(iOS)
        return session?.isWatchAppInstalled ?? false
        #else
        return true
        #endif
    }
    
    // Combine publishers
    private let stateSubject = CurrentValueSubject<WatchConnectivityState, Never>(
        WatchConnectivityState(
            isReachable: false,
            isPaired: false,
            isWatchAppInstalled: false,
            activationState: .notActivated
        )
    )
    
    nonisolated var connectivityStatePublisher: AnyPublisher<WatchConnectivityState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    // Session management
    private var session: WCSession?
    private var activationContinuation: CheckedContinuation<Void, Never>?
    private var messageContinuations: [String: CheckedContinuation<[String: Any], Error>] = [:]
    
    // Rate limiting
    private let messageRateLimit = 10 // messages per minute
    private var messageTimestamps: [Date] = []
    
    override private init() {
        super.init()
        
        // Activate session immediately for singleton
        Task {
            await activate()
        }
    }
    
    // MARK: - Public Methods
    
    func activate() async {
        guard WCSession.isSupported() else {
            FameFitLogger.warning("Watch Connectivity not supported", category: FameFitLogger.general)
            return
        }
        
        await withCheckedContinuation { continuation in
            self.activationContinuation = continuation
            
            // Setup session synchronously since delegate methods are nonisolated
            let session = WCSession.default
            session.delegate = self
            self.session = session
            session.activate()
        }
    }
    
    func startWorkout(type: Int) async throws {
        let message: [String: Any] = [
            "command": "startWorkout",
            "workoutType": type,
            "timestamp": Date()
        ]
        
        _ = try await sendMessage(message)
        FameFitLogger.info("Started workout on watch: type \(type)", category: FameFitLogger.general)
    }
    
    func syncData(_ data: [String: Any]) async throws {
        guard let session = session else {
            throw WatchConnectivityError.sessionNotActivated
        }
        
        guard session.isReachable else {
            // If not reachable, use transferUserInfo for background sync
            await transferUserInfo(data)
            return
        }
        
        // If reachable, use sendMessage for immediate sync
        _ = try await sendMessage(data)
    }
    
    func sendMessage(_ message: [String: Any]) async throws -> [String: Any] {
        guard let session = session else {
            throw WatchConnectivityError.sessionNotActivated
        }
        
        guard session.isReachable else {
            throw WatchConnectivityError.notReachable
        }
        
        // Check rate limiting
        try checkRateLimit()
        
        let messageID = UUID().uuidString
        var messageWithID = message
        messageWithID["messageID"] = messageID
        
        return try await withCheckedThrowingContinuation { continuation in
            self.messageContinuations[messageID] = continuation
            
            session.sendMessage(messageWithID, replyHandler: { [weak self] reply in
                self?.messageContinuations.removeValue(forKey: messageID)
                continuation.resume(returning: reply)
            }, errorHandler: { [weak self] error in
                self?.messageContinuations.removeValue(forKey: messageID)
                FameFitLogger.error("Message send failed", error: error, category: FameFitLogger.general)
                continuation.resume(throwing: WatchConnectivityError.messageFailed(error))
            })
            
            // Add timeout
            Task {
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                if self.messageContinuations[messageID] != nil {
                    self.messageContinuations.removeValue(forKey: messageID)
                    continuation.resume(throwing: WatchConnectivityError.timeout)
                }
            }
        }
    }
    
    func transferUserInfo(_ userInfo: [String: Any]) async {
        guard let session = session else {
            FameFitLogger.warning("Cannot transfer user info: session not activated", category: FameFitLogger.general)
            return
        }
        
        var info = userInfo
        info["timestamp"] = Date()
        
        session.transferUserInfo(info)
        FameFitLogger.info("Queued user info transfer", category: FameFitLogger.general)
    }
    
    func transferFile(_ file: URL, metadata: [String: Any]? = nil) async throws {
        guard let session = session else {
            throw WatchConnectivityError.sessionNotActivated
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let transfer = session.transferFile(file, metadata: metadata)
            
            // Monitor transfer progress
            Task {
                while !transfer.isTransferring && transfer.progress.fractionCompleted < 1.0 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
                
                if transfer.progress.fractionCompleted >= 1.0 {
                    continuation.resume()
                } else if transfer.progress.isCancelled {
                    continuation.resume(throwing: WatchConnectivityError.transferFailed(
                        NSError(domain: "WatchConnectivity", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transfer cancelled"])
                    ))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateState() {
        guard let session = session else { return }
        
        Task { @MainActor in
            _isReachable = session.isReachable
            
            #if os(iOS)
            _isPaired = session.isPaired
            _isWatchAppInstalled = session.isWatchAppInstalled
            #else
            _isPaired = true
            _isWatchAppInstalled = true
            #endif
        }
        
        #if os(iOS)
        let newState = WatchConnectivityState(
            isReachable: session.isReachable,
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            activationState: session.activationState
        )
        #else
        let newState = WatchConnectivityState(
            isReachable: session.isReachable,
            isPaired: true,
            isWatchAppInstalled: true,
            activationState: session.activationState
        )
        #endif
        
        stateSubject.send(newState)
    }
    
    private func checkRateLimit() throws {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        
        // Remove old timestamps
        messageTimestamps.removeAll { $0 < oneMinuteAgo }
        
        // Check if we're at the limit
        if messageTimestamps.count >= messageRateLimit {
            throw WatchConnectivityError.messageFailed(
                NSError(domain: "WatchConnectivity", code: -1, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"])
            )
        }
        
        messageTimestamps.append(now)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivitySingleton: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            FameFitLogger.error("WCSession activation failed", error: error, category: FameFitLogger.general)
        } else {
            FameFitLogger.debug("WCSession activated: \(activationState.rawValue)", category: FameFitLogger.general)
        }
        
        updateState()
        activationContinuation?.resume()
        activationContinuation = nil
    }
    
    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        FameFitLogger.info("WCSession became inactive", category: FameFitLogger.general)
        updateState()
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        FameFitLogger.info("WCSession deactivated", category: FameFitLogger.general)
        // Reactivate the session
        Task {
            await activate()
        }
    }
    #endif
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        FameFitLogger.info("WCSession reachability changed: \(session.isReachable)", category: FameFitLogger.general)
        updateState()
    }
    
    // MARK: - Message Handling
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        FameFitLogger.info("Received message: \(message.keys.joined(separator: ", "))", category: FameFitLogger.general)
        // Handle incoming messages
        handleIncomingMessage(message)
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        FameFitLogger.info("Received message with reply: \(message.keys.joined(separator: ", "))", category: FameFitLogger.general)
        
        // Handle message and send reply
        let reply = handleIncomingMessageWithReply(message)
        replyHandler(reply)
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        FameFitLogger.info("Received user info: \(userInfo.keys.joined(separator: ", "))", category: FameFitLogger.general)
        // Handle background user info transfers
        handleIncomingUserInfo(userInfo)
    }
    
    // MARK: - Message Processing
    
    private func handleIncomingMessage(_ message: [String: Any]) {
        // Process different message types
        if let command = message["command"] as? String {
            switch command {
            case "workoutCompleted":
                NotificationCenter.default.post(
                    name: .watchWorkoutCompleted,
                    object: nil,
                    userInfo: message
                )
            case "syncRequest":
                Task {
                    await handleSyncRequest()
                }
            default:
                FameFitLogger.debug("Unknown command: \(command)", category: FameFitLogger.general)
            }
        }
    }
    
    private func handleIncomingMessageWithReply(_ message: [String: Any]) -> [String: Any] {
        // Process message and return appropriate reply
        var reply: [String: Any] = ["status": "received"]
        
        if let command = message["command"] as? String {
            switch command {
            case "ping":
                reply = ["status": "pong", "timestamp": Date()]
            case "getStatus":
                reply = [
                    "status": "ok",
                    "isReachable": isReachable,
                    "isPaired": isPaired,
                    "isWatchAppInstalled": isWatchAppInstalled
                ]
            default:
                reply["command"] = command
            }
        }
        
        return reply
    }
    
    private func handleIncomingUserInfo(_ userInfo: [String: Any]) {
        // Process background transfers
        NotificationCenter.default.post(
            name: .watchBackgroundSync,
            object: nil,
            userInfo: userInfo
        )
    }
    
    private func handleSyncRequest() async {
        // Gather data to sync
        let syncData: [String: Any] = [
            "command": "syncResponse",
            "timestamp": Date()
            // Add relevant data to sync
        ]
        
        try? await self.syncData(syncData)
    }
    
    // MARK: - Legacy Compatibility Methods
    
    func sendGroupWorkoutCommand(workoutID: String, workoutName: String, workoutType: Int, isHost: Bool) {
        FameFitLogger.info("📱 sendGroupWorkoutCommand - ID: \(workoutID), Name: \(workoutName), Type: \(workoutType), Host: \(isHost)", category: FameFitLogger.sync)
        
        guard let session = session else {
            FameFitLogger.error("📱 WCSession not initialized", category: FameFitLogger.sync)
            return
        }
        
        #if DEBUG
        // Debug WCSession state
        FameFitLogger.debug("📱 WCSession state: isSupported=\(WCSession.isSupported()), activationState=\(session.activationState.rawValue), isPaired=\(isPaired), isWatchAppInstalled=\(isWatchAppInstalled), isReachable=\(isReachable)", category: FameFitLogger.sync)
        
        // Development warning if Watch app appears not installed
        if isPaired && !isWatchAppInstalled {
            FameFitLogger.warning("⚠️ Watch communication unavailable in Xcode builds. Use TestFlight for testing Watch↔iPhone features.", category: FameFitLogger.sync)
            // Note: We still try to send as it sometimes works
        }
        #endif
        
        // Check if Watch is paired
        if !isPaired {
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
            try session.updateApplicationContext(context)
            FameFitLogger.info("📱✅ Successfully updated application context", category: FameFitLogger.sync)
            FameFitLogger.debug("📱 Current context: \(session.applicationContext)", category: FameFitLogger.sync)
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
        let transfer = session.transferUserInfo(userInfo)
        FameFitLogger.info("📱 Sent via transferUserInfo - transferring: \(transfer.isTransferring)", category: FameFitLogger.sync)
        
        // Also try sending a file transfer as ultimate fallback
        if let data = try? JSONSerialization.data(withJSONObject: userInfo, options: []) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("workout_\(Date().timeIntervalSince1970).json")
            do {
                try data.write(to: url)
                _ = session.transferFile(url, metadata: ["type": "groupWorkout"])
                FameFitLogger.info("📱 Also sent via file transfer as backup", category: FameFitLogger.sync)
            } catch {
                FameFitLogger.error("📱 Failed to create file for transfer: \(error)", category: FameFitLogger.sync)
            }
        }
        
        // Also try immediate message if reachable
        if session.isReachable {
            FameFitLogger.info("✅ Watch is reachable, sending immediate message", category: FameFitLogger.sync)
            
            let message: [String: Any] = [
                "command": "startGroupWorkout",
                "workoutID": workoutID,
                "workoutName": workoutName,
                "workoutType": workoutType,
                "isHost": isHost,
                "timestamp": Date()
            ]
            
            FameFitLogger.debug("📱 Sending message to Watch: \(message)", category: FameFitLogger.sync)
            
            session.sendMessage(message, replyHandler: { response in
                FameFitLogger.info("✅ Watch acknowledged group workout: \(response)", category: FameFitLogger.sync)
            }, errorHandler: { error in
                FameFitLogger.error("❌ Error sending group workout to watch: \(error)", category: FameFitLogger.sync)
                
                // Try application context as fallback
                do {
                    try session.updateApplicationContext(message)
                    FameFitLogger.info("📱 Sent group workout via application context as fallback after error", category: FameFitLogger.sync)
                } catch {
                    FameFitLogger.error("❌ Failed to update application context: \(error)", category: FameFitLogger.sync)
                }
            })
        } else {
            FameFitLogger.warning("⚠️ Watch not immediately reachable, but data sent via context and transferUserInfo", category: FameFitLogger.sync)
        }
    }
    
    func sendUserData(username: String, totalXP: Int) {
        guard let session = session else {
            FameFitLogger.warning("Cannot send user data: session not activated", category: FameFitLogger.sync)
            return
        }
        
        guard session.isReachable else {
            FameFitLogger.warning("Watch not reachable for user data update", category: FameFitLogger.sync)
            return
        }
        
        let message: [String: Any] = [
            "command": "updateUserData",
            "username": username,
            "totalXP": totalXP,
            "timestamp": Date()
        ]
        
        session.sendMessage(message, replyHandler: { response in
            FameFitLogger.info("Watch acknowledged user data update: \(response)", category: FameFitLogger.sync)
        }, errorHandler: { error in
            FameFitLogger.error("Error sending user data to watch: \(error)", category: FameFitLogger.sync)
            // Try to send via application context as fallback
            do {
                try session.updateApplicationContext(message)
            } catch {
                FameFitLogger.error("Failed to update application context: \(error)", category: FameFitLogger.sync)
            }
        })
    }
    
    func checkConnection(completion: @escaping (Bool) -> Void) {
        guard let session = session else {
            completion(false)
            return
        }
        
        guard session.isReachable else {
            completion(false)
            return
        }
        
        session.sendMessage(["command": "ping"], replyHandler: { _ in
            completion(true)
        }, errorHandler: { _ in
            completion(false)
        })
    }
    
    func forceRefreshSessionState() {
        FameFitLogger.info("📱 Force refreshing WCSession state...", category: FameFitLogger.sync)
        
        guard let session = session else {
            FameFitLogger.warning("Cannot force refresh: session not initialized", category: FameFitLogger.sync)
            return
        }
        
        // Deactivate and reactivate the session
        if session.activationState == .activated {
            #if os(iOS)
            // On iOS, we can deactivate and reactivate
            session.delegate = nil
            session.delegate = self
            session.activate()
            #endif
        } else {
            // If not activated, just activate
            session.activate()
        }
        
        // Update our local state
        updateState()
        
        #if os(iOS)
        FameFitLogger.info("📱 After force refresh:", category: FameFitLogger.sync)
        FameFitLogger.info("  - isPaired: \(session.isPaired)", category: FameFitLogger.sync)
        FameFitLogger.info("  - isWatchAppInstalled: \(session.isWatchAppInstalled)", category: FameFitLogger.sync)
        FameFitLogger.info("  - isReachable: \(session.isReachable)", category: FameFitLogger.sync)
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchWorkoutCompleted = Notification.Name("watchWorkoutCompleted")
    static let watchBackgroundSync = Notification.Name("watchBackgroundSync")
}
