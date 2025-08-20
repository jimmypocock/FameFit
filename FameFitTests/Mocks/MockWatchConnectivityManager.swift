//
//  MockWatchConnectivityManager.swift
//  FameFitTests
//
//  Mock implementation of WatchConnectivityProtocol for testing
//

import Combine
@testable import FameFit
import Foundation
import WatchConnectivity

final class MockWatchConnectivityManager: WatchConnectivityProtocol {
    // MARK: - Mock State Properties
    
    var isReachable: Bool = true
    var isPaired: Bool = true
    var isWatchAppInstalled: Bool = true
    
    // MARK: - Publishers
    
    private let connectivityStateSubject = CurrentValueSubject<WatchConnectivityState, Never>(
        WatchConnectivityState(
            isReachable: true,
            isPaired: true,
            isWatchAppInstalled: true,
            activationState: .activated
        )
    )
    
    var connectivityStatePublisher: AnyPublisher<WatchConnectivityState, Never> {
        connectivityStateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Test Control Properties
    
    var shouldFailActivation = false
    var shouldFailStartWorkout = false
    var shouldFailSyncData = false
    var shouldFailSendMessage = false
    var shouldFailTransferFile = false
    
    // MARK: - Call Tracking
    
    var activateCalled = false
    var startWorkoutCalled = false
    var syncDataCalled = false
    var sendMessageCalled = false
    var transferUserInfoCalled = false
    var transferFileCalled = false
    var sendGroupWorkoutCommandCalled = false
    var sendUserDataCalled = false
    var checkConnectionCalled = false
    var forceRefreshSessionStateCalled = false
    
    // MARK: - Data Tracking
    
    var lastWorkoutType: Int?
    var lastSyncData: [String: Any]?
    var lastMessage: [String: Any]?
    var lastUserInfo: [String: Any]?
    var lastFileURL: URL?
    var lastFileMetadata: [String: Any]?
    var lastGroupWorkoutID: String?
    var lastUsername: String?
    var lastTotalXP: Int?
    var lastCheckConnectionCompletion: ((Bool) -> Void)?
    
    // MARK: - Protocol Implementation
    
    func activate() async {
        activateCalled = true
        
        if shouldFailActivation {
            // Update state to show failure
            connectivityStateSubject.send(WatchConnectivityState(
                isReachable: false,
                isPaired: false,
                isWatchAppInstalled: false,
                activationState: .notActivated
            ))
        }
    }
    
    func startWorkout(type: Int) async throws {
        startWorkoutCalled = true
        lastWorkoutType = type
        
        if shouldFailStartWorkout {
            throw NSError(domain: "MockWatchConnectivity", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock start workout error"])
        }
    }
    
    func syncData(_ data: [String: Any]) async throws {
        syncDataCalled = true
        lastSyncData = data
        
        if shouldFailSyncData {
            throw NSError(domain: "MockWatchConnectivity", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock sync data error"])
        }
    }
    
    func sendMessage(_ message: [String: Any]) async throws -> [String: Any] {
        sendMessageCalled = true
        lastMessage = message
        
        if shouldFailSendMessage {
            throw NSError(domain: "MockWatchConnectivity", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock send message error"])
        }
        
        // Return mock response
        return ["status": "success", "echo": message]
    }
    
    func transferUserInfo(_ userInfo: [String: Any]) async {
        transferUserInfoCalled = true
        lastUserInfo = userInfo
    }
    
    func transferFile(_ file: URL, metadata: [String: Any]?) async throws {
        transferFileCalled = true
        lastFileURL = file
        lastFileMetadata = metadata
        
        if shouldFailTransferFile {
            throw NSError(domain: "MockWatchConnectivity", code: 4, userInfo: [NSLocalizedDescriptionKey: "Mock transfer file error"])
        }
    }
    
    // MARK: - Legacy Methods
    
    func sendGroupWorkoutCommand(workoutID: String, workoutName: String, workoutType: Int, isHost: Bool) {
        sendGroupWorkoutCommandCalled = true
        lastGroupWorkoutID = workoutID
        lastWorkoutType = workoutType
    }
    
    func sendUserData(username: String, totalXP: Int) {
        sendUserDataCalled = true
        lastUsername = username
        lastTotalXP = totalXP
    }
    
    func checkConnection(completion: @escaping (Bool) -> Void) {
        checkConnectionCalled = true
        lastCheckConnectionCompletion = completion
        completion(isReachable)
    }
    
    func forceRefreshSessionState() {
        forceRefreshSessionStateCalled = true
        
        // Emit updated state
        connectivityStateSubject.send(WatchConnectivityState(
            isReachable: isReachable,
            isPaired: isPaired,
            isWatchAppInstalled: isWatchAppInstalled,
            activationState: .activated
        ))
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        // Reset call tracking
        activateCalled = false
        startWorkoutCalled = false
        syncDataCalled = false
        sendMessageCalled = false
        transferUserInfoCalled = false
        transferFileCalled = false
        sendGroupWorkoutCommandCalled = false
        sendUserDataCalled = false
        checkConnectionCalled = false
        forceRefreshSessionStateCalled = false
        
        // Reset data tracking
        lastWorkoutType = nil
        lastSyncData = nil
        lastMessage = nil
        lastUserInfo = nil
        lastFileURL = nil
        lastFileMetadata = nil
        lastGroupWorkoutID = nil
        lastUsername = nil
        lastTotalXP = nil
        lastCheckConnectionCompletion = nil
        
        // Reset control flags
        shouldFailActivation = false
        shouldFailStartWorkout = false
        shouldFailSyncData = false
        shouldFailSendMessage = false
        shouldFailTransferFile = false
        
        // Reset state
        isReachable = true
        isPaired = true
        isWatchAppInstalled = true
        
        connectivityStateSubject.send(WatchConnectivityState(
            isReachable: true,
            isPaired: true,
            isWatchAppInstalled: true,
            activationState: .activated
        ))
    }
    
    func updateState(isReachable: Bool? = nil, isPaired: Bool? = nil, isWatchAppInstalled: Bool? = nil) {
        if let isReachable = isReachable {
            self.isReachable = isReachable
        }
        if let isPaired = isPaired {
            self.isPaired = isPaired
        }
        if let isWatchAppInstalled = isWatchAppInstalled {
            self.isWatchAppInstalled = isWatchAppInstalled
        }
        
        connectivityStateSubject.send(WatchConnectivityState(
            isReachable: self.isReachable,
            isPaired: self.isPaired,
            isWatchAppInstalled: self.isWatchAppInstalled,
            activationState: .activated
        ))
    }
}