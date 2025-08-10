//
//  GroupWorkoutSyncService.swift
//  FameFit
//
//  Manages group workout synchronization between Watch and iPhone
//  Supports both real device and simulator testing
//

import Foundation
import CloudKit
import Combine
import CoreLocation
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Manages synchronization of group workouts between devices
@MainActor
public final class GroupWorkoutSyncService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current sync state
    @Published public private(set) var syncState: SyncState = .idle
    
    /// Active group workout if any
    @Published public private(set) var activeGroupWorkout: GroupWorkout?
    
    /// Current participant metrics
    @Published public private(set) var participantMetrics: [String: WorkoutMetrics] = [:]
    
    /// Connection status to Watch/Phone
    @Published public private(set) var isConnected = false
    
    /// Testing mode enabled (uses mock data)
    @Published public var isTestingMode = false
    
    // MARK: - Types
    
    public enum SyncState {
        case idle
        case connecting
        case ready
        case syncing
        case error(String)
    }
    
    
    // MARK: - Private Properties
    
    private let cloudKitManager: any CloudKitProtocol
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 5.0
    
    // Testing support
    private var mockDataTimer: Timer?
    
    // MARK: - Initialization
    
    public init(cloudKitManager: any CloudKitProtocol) {
        self.cloudKitManager = cloudKitManager
        
        setupTestingModeIfNeeded()
        setupCloudKitSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// Start syncing for a group workout
    public func startGroupWorkoutSync(workout: GroupWorkout, isHost: Bool) async throws {
        FameFitLogger.info("📱⌚ Starting group workout sync: \(workout.name)", category: .sync)
        
        syncState = .connecting
        activeGroupWorkout = workout
        
        if isTestingMode {
            // In testing mode, simulate connection
            await simulateConnection()
        } else {
            // Real mode - set up CloudKit sync
            try await setupRealTimeSync(for: workout)
        }
        
        // Start periodic metric updates
        startMetricSync()
        
        syncState = .syncing
    }
    
    /// Update metrics from Watch
    public func updateMetrics(
        heartRate: Double,
        activeEnergy: Double,
        distance: Double,
        elapsedTime: TimeInterval
    ) async {
        guard let workout = activeGroupWorkout,
              let userID = await getCurrentUserID() else { return }
        
        let metrics = WorkoutMetrics(
            workoutID: workout.id,
            userID: userID,
            workoutType: workout.workoutType.displayName,
            groupWorkoutID: workout.id,
            sharingLevel: .groupOnly,
            heartRate: heartRate,
            activeEnergyBurned: activeEnergy,
            distance: distance,
            elapsedTime: elapsedTime
        )
        
        // Update local state
        participantMetrics[userID] = metrics
        
        // Sync to CloudKit
        if !isTestingMode {
            await syncMetricsToCloudKit(metrics, workoutID: workout.id)
        }
    }
    
    /// Stop syncing
    public func stopSync() {
        FameFitLogger.info("📱⌚ Stopping group workout sync", category: .sync)
        
        syncTimer?.invalidate()
        syncTimer = nil
        mockDataTimer?.invalidate()
        mockDataTimer = nil
        
        activeGroupWorkout = nil
        participantMetrics.removeAll()
        syncState = .idle
    }
    
    // MARK: - Testing Support
    
    /// Enable testing mode with mock data
    public func enableTestingMode() {
        isTestingMode = true
        setupMockDataGeneration()
    }
    
    private func setupTestingModeIfNeeded() {
        // Auto-enable testing mode in simulator
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["ENABLE_GROUP_WORKOUT_TESTING"] == "1" {
            FameFitLogger.info("📱⌚ Auto-enabling testing mode for group workouts", category: .sync)
            enableTestingMode()
        }
        #endif
    }
    
    private func simulateConnection() async {
        // Simulate connection delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        isConnected = true
        syncState = .ready
    }
    
    private func setupMockDataGeneration() {
        // Generate mock participant data
        mockDataTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                self.generateMockParticipantData()
            }
        }
    }
    
    private func generateMockParticipantData() {
        let mockParticipants = ["User1", "User2", "User3"]
        
        for participant in mockParticipants {
            let metrics = WorkoutMetrics(
                workoutID: workout.id,
                userID: participant,
                workoutType: workout.workoutType.displayName,
                groupWorkoutID: workout.id,
                sharingLevel: .groupOnly,
                heartRate: Double.random(in: 120...180),
                activeEnergyBurned: Double.random(in: 100...500),
                distance: Double.random(in: 1000...5000),
                elapsedTime: Date().timeIntervalSince(workout.scheduledStart)
            )
            participantMetrics[participant] = metrics
        }
    }
    
    // MARK: - Real Sync Implementation
    
    private func setupRealTimeSync(for workout: GroupWorkout) async throws {
        // Subscribe to workout metrics updates
        let subscription = CKQuerySubscription(
            recordType: "WorkoutMetrics",
            predicate: NSPredicate(format: "groupWorkoutID == %@", workout.id),
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        let notification = CKSubscription.NotificationInfo()
        notification.shouldSendContentAvailable = true
        subscription.notificationInfo = notification
        
        do {
            _ = try await cloudKitManager.database.save(subscription)
            FameFitLogger.info("📱⌚ Subscribed to workout metrics updates", category: .sync)
        } catch {
            FameFitLogger.error("Failed to create metrics subscription", error: error, category: .sync)
        }
    }
    
    private func startMetricSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.fetchLatestMetrics()
            }
        }
    }
    
    private func fetchLatestMetrics() async {
        guard let workout = activeGroupWorkout else { return }
        
        if isTestingMode {
            // Testing mode already generates mock data
            return
        }
        
        // Fetch real metrics from CloudKit
        let predicate = NSPredicate(format: "groupWorkoutID == %@", workout.id)
        
        do {
            let records = try await cloudKitManager.fetchRecords(
                ofType: "WorkoutMetrics",
                predicate: predicate,
                sortDescriptors: [NSSortDescriptor(key: "createdTimestamp", ascending: false)],
                limit: 50
            )
            
            // Process metrics
            for record in records {
                if let metrics = WorkoutMetrics(from: record) {
                    participantMetrics[metrics.userID] = metrics
                }
            }
        } catch {
            FameFitLogger.error("Failed to fetch metrics", error: error, category: .sync)
        }
    }
    
    private func syncMetricsToCloudKit(_ metrics: WorkoutMetrics, workoutID: String) async {
        let record = metrics.toCKRecord()
        
        do {
            _ = try await cloudKitManager.save(record)
        } catch {
            FameFitLogger.error("Failed to sync metrics", error: error, category: .sync)
        }
    }
    
    private func setupCloudKitSubscriptions() {
        // Set up CloudKit change notifications
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { _ in
                Task { @MainActor in
                    // Handle account changes
                    if self.activeGroupWorkout != nil {
                        self.syncState = .error("CloudKit account changed")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func getCurrentUserID() async -> String? {
        if isTestingMode {
            return "TestUser"
        }
        return try? await cloudKitManager.getCurrentUserID()
    }
}

// MARK: - Logger Extension

extension FameFitLogger.Category {
    static let sync = FameFitLogger.Category("sync")
}