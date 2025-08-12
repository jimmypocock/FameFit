//
//  RealWatchConnectivityService.swift
//  FameFit Watch App
//
//  Implements WatchConnectivityService protocol using WCSession
//

#if os(watchOS)
import Foundation
import WatchConnectivity
import os.log

/// Real implementation of WatchConnectivityService for Watch app
final class RealWatchConnectivityService: NSObject, WatchConnectivityService {
    
    // MARK: - Properties
    
    private let session: WCSession
    private var pendingWorkoutUpdates: [WorkoutUpdate] = []
    
    // MARK: - Protocol Properties
    
    var isReachable: Bool {
        session.isReachable
    }
    
    var isPaired: Bool {
        #if os(watchOS)
        // On watchOS, we check if iPhone is paired
        return session.isCompanionAppInstalled
        #else
        return session.isPaired
        #endif
    }
    
    // MARK: - Initialization
    
    override init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Protocol Methods
    
    func sendWorkoutUpdate(_ update: WorkoutUpdate) async {
        FameFitLogger.info("📤 Sending workout update to iPhone: \(update.workoutID)", category: FameFitLogger.sync)
        
        // Prepare the message
        var message: [String: Any] = [
            "command": "workoutCompleted",
            "workoutID": update.workoutID,
            "status": update.status.rawValue,
            "timestamp": update.timestamp
        ]
        
        // Add metrics if available
        if let metrics = update.metrics {
            message["metrics"] = [
                "heartRate": metrics.heartRate,
                "activeEnergy": metrics.activeEnergy,
                "distance": metrics.distance,
                "elapsedTime": metrics.elapsedTime
            ]
        }
        
        // Add group workout ID if applicable
        if let groupWorkoutID = update.groupWorkoutID {
            message["groupWorkoutID"] = groupWorkoutID
        }
        
        // Send the message
        if session.isReachable {
            session.sendMessage(message, replyHandler: { response in
                FameFitLogger.info("✅ iPhone acknowledged workout: \(response)", category: FameFitLogger.sync)
            }, errorHandler: { error in
                FameFitLogger.error("❌ Failed to send workout to iPhone", error: error, category: FameFitLogger.sync)
                // Queue for retry
                self.pendingWorkoutUpdates.append(update)
            })
        } else {
            FameFitLogger.warning("⚠️ iPhone not reachable, queuing workout update", category: FameFitLogger.sync)
            // Queue for later when iPhone becomes reachable
            pendingWorkoutUpdates.append(update)
            
            // Try using userInfo transfer as fallback (works even when not reachable)
            session.transferUserInfo(message)
        }
    }
    
    func sendMetricsBatch(_ metrics: [WorkoutMetricsData]) async {
        // Convert metrics to dictionary format
        let metricsData = metrics.map { metric in
            [
                "heartRate": metric.heartRate,
                "activeEnergy": metric.activeEnergy,
                "distance": metric.distance,
                "elapsedTime": metric.elapsedTime,
                "timestamp": metric.timestamp
            ]
        }
        
        let message: [String: Any] = [
            "command": "metricsBatch",
            "metrics": metricsData
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                FameFitLogger.error("Failed to send metrics batch", error: error, category: FameFitLogger.sync)
            })
        }
    }
    
    func requestUserProfile() async throws -> UserProfile {
        guard session.isReachable else {
            throw WatchConnectivityError.iPhoneNotReachable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                ["request": "userProfile"],
                replyHandler: { response in
                    if let profileData = response["userProfile"] as? Data,
                       let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                        continuation.resume(returning: profile)
                    } else {
                        continuation.resume(throwing: WatchConnectivityError.invalidResponse)
                    }
                },
                errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }
    
    func requestGroupWorkouts() async throws -> [WatchGroupWorkout] {
        guard session.isReachable else {
            throw WatchConnectivityError.iPhoneNotReachable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                ["request": "groupWorkouts"],
                replyHandler: { response in
                    if let workoutsData = response["groupWorkouts"] as? Data,
                       let workouts = try? JSONDecoder().decode([WatchGroupWorkout].self, from: workoutsData) {
                        continuation.resume(returning: workouts)
                    } else {
                        continuation.resume(returning: [])
                    }
                },
                errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }
    
    func requestChallenges() async throws -> [ChallengeInfo] {
        guard session.isReachable else {
            throw WatchConnectivityError.iPhoneNotReachable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(
                ["request": "challenges"],
                replyHandler: { response in
                    if let challengesData = response["challenges"] as? Data,
                       let challenges = try? JSONDecoder().decode([ChallengeInfo].self, from: challengesData) {
                        continuation.resume(returning: challenges)
                    } else {
                        continuation.resume(returning: [])
                    }
                },
                errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }
    
    func setupHandlers() {
        // Handlers are set up via delegate methods
        FameFitLogger.info("⌚ WatchConnectivity handlers configured", category: FameFitLogger.sync)
    }
    
    // MARK: - Private Methods
    
    private func processPendingUpdates() {
        guard session.isReachable, !pendingWorkoutUpdates.isEmpty else { return }
        
        FameFitLogger.info("📤 Processing \(pendingWorkoutUpdates.count) pending workout updates", category: FameFitLogger.sync)
        
        let updates = pendingWorkoutUpdates
        pendingWorkoutUpdates.removeAll()
        
        Task {
            for update in updates {
                await sendWorkoutUpdate(update)
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension RealWatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            FameFitLogger.error("⌚ WCSession activation failed", error: error, category: FameFitLogger.sync)
            return
        }
        
        FameFitLogger.info("⌚ WCSession activated - state: \(activationState.rawValue)", category: FameFitLogger.sync)
        
        // Process any pending updates
        if activationState == .activated {
            processPendingUpdates()
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        FameFitLogger.info("⌚ iPhone reachability changed: \(session.isReachable)", category: FameFitLogger.sync)
        
        if session.isReachable {
            processPendingUpdates()
        }
    }
}

// MARK: - Error Types

enum WatchConnectivityError: LocalizedError {
    case iPhoneNotReachable
    case invalidResponse
    case sendFailed
    
    var errorDescription: String? {
        switch self {
        case .iPhoneNotReachable:
            return "iPhone is not reachable"
        case .invalidResponse:
            return "Invalid response from iPhone"
        case .sendFailed:
            return "Failed to send data to iPhone"
        }
    }
}
#endif