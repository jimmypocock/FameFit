//
//  WatchConnectivityProtocol.swift
//  FameFit
//
//  Protocol for watch connectivity operations
//

import Combine
import Foundation
import WatchConnectivity

protocol WatchConnectivityProtocol: AnyObject {
    var isReachable: Bool { get }
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    
    var connectivityStatePublisher: AnyPublisher<WatchConnectivityState, Never> { get }
    
    func activate() async
    func startWorkout(type: Int) async throws
    func syncData(_ data: [String: Any]) async throws
    func sendMessage(_ message: [String: Any]) async throws -> [String: Any]
    func transferUserInfo(_ userInfo: [String: Any]) async
    func transferFile(_ file: URL, metadata: [String: Any]?) async throws
    
    // Legacy compatibility methods
    func sendGroupWorkoutCommand(workoutID: String, workoutName: String, workoutType: Int, isHost: Bool)
    func sendUserData(username: String, totalXP: Int)
    func checkConnection(completion: @escaping (Bool) -> Void)
    func forceRefreshSessionState()
}

// MARK: - Supporting Types

public struct WatchConnectivityState {
    public let isReachable: Bool
    public let isPaired: Bool
    public let isWatchAppInstalled: Bool
    public let activationState: WCSessionActivationState
    
    public init(isReachable: Bool, isPaired: Bool, isWatchAppInstalled: Bool, activationState: WCSessionActivationState) {
        self.isReachable = isReachable
        self.isPaired = isPaired
        self.isWatchAppInstalled = isWatchAppInstalled
        self.activationState = activationState
    }
}

