//
//  GroupWorkoutCoordinator.swift
//  FameFit
//
//  Coordinates HealthKit and CloudKit for group workouts
//  Manages bidirectional sync, offline support, and reconnection
//

import Combine
import Foundation
import HealthKit
import WatchConnectivity

/// Coordinates group workout sessions between HealthKit and CloudKit
@MainActor
final class GroupWorkoutCoordinator: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var isInGroupWorkout = false
    @Published private(set) var currentGroupWorkout: GroupWorkout?
    @Published private(set) var currentParticipation: GroupWorkoutParticipant?
    @Published private(set) var participantMetrics: [String: GroupWorkoutData] = [:]
    @Published private(set) var aggregateMetrics: AggregateWorkoutMetrics?
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var syncStatus: SyncStatus = .idle
    
    // Current workout metrics (updated from Watch or local HealthKit)
    @Published var heartRate: Double = 0
    @Published var activeEnergy: Double = 0
    @Published var distance: Double = 0
    @Published var averageHeartRate: Double = 0
    
    // MARK: - Dependencies
    
    private let groupWorkoutService: any GroupWorkoutServiceProtocol
    private let healthKitService: any HealthKitService
    private let cloudKitManager: any CloudKitManaging
    private let userProfileService: any UserProfileServicing
    private let notificationManager: any NotificationManaging
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 5.0 // Update every 5 seconds
    private let offlineCache = GroupWorkoutOfflineCache()
    private var reconnectionAttempts = 0
    private let maxReconnectionAttempts = 3
    
    // Session tracking
    private var healthKitWorkoutID: String?
    private var groupWorkoutID: String?
    private var participantID: String?
    private var workoutStartTime: Date?
    private var isHost = false
    
    // MARK: - Initialization
    
    init(
        groupWorkoutService: any GroupWorkoutServiceProtocol,
        healthKitService: any HealthKitService,
        cloudKitManager: any CloudKitManaging,
        userProfileService: any UserProfileServicing,
        notificationManager: any NotificationManaging
    ) {
        self.groupWorkoutService = groupWorkoutService
        self.healthKitService = healthKitService
        self.cloudKitManager = cloudKitManager
        self.userProfileService = userProfileService
        self.notificationManager = notificationManager
        
        super.init()
        
        setupObservers()
        checkForExistingSession()
    }
    
    // MARK: - Public Methods
    
    /// Start a group workout session
    func startGroupWorkout(_ groupWorkout: GroupWorkout, asHost: Bool = false) async throws {
        FameFitLogger.info("🏋️ Starting group workout: \(groupWorkout.name), asHost: \(asHost)", category: FameFitLogger.workout)
        
        // Check HealthKit authorization
        try await verifyHealthKitAuthorization()
        
        // Store group workout info
        self.currentGroupWorkout = groupWorkout
        self.groupWorkoutID = groupWorkout.id
        self.isHost = asHost
        self.workoutStartTime = Date()
        
        // Update CloudKit status if host
        if asHost {
            _ = try await groupWorkoutService.startGroupWorkout(groupWorkout.id)
        }
        
        // Create participant entry
        let userId = cloudKitManager.currentUserID ?? "unknown"
        let profile = try await userProfileService.fetchProfileByUserID(userId)
        
        let participant = GroupWorkoutParticipant(
            groupWorkoutId: groupWorkout.id,
            userId: userId,
            username: profile.username,
            profileImageURL: profile.profileImageURL,
            status: .active,
            workoutData: GroupWorkoutData(
                startTime: Date(),
                endTime: nil,
                totalEnergyBurned: 0,
                totalDistance: 0,
                averageHeartRate: 0,
                currentHeartRate: 0,
                lastUpdated: Date()
            )
        )
        
        self.currentParticipation = participant
        self.participantID = participant.id
        
        // Store metadata for later retrieval
        UserDefaults.standard.set(groupWorkout.id, forKey: "activeGroupWorkoutID")
        UserDefaults.standard.set(Date(), forKey: "activeGroupWorkoutStartTime")
        
        // Start metric updates
        startMetricUpdates()
        
        // Update state
        isInGroupWorkout = true
        connectionState = .connected
        
        // Notify - using feature announcement as closest match
        await notificationManager.notifyFeatureAnnouncement(
            feature: "Group Workout Started",
            description: "You've joined \(groupWorkout.name)"
        )
    }
    
    /// Join an active group workout
    func joinActiveGroupWorkout(_ groupWorkout: GroupWorkout) async throws {
        FameFitLogger.info("🏋️ Joining active group workout: \(groupWorkout.name)", category: FameFitLogger.workout)
        
        // Late joiner - track actual join time
        workoutStartTime = Date()
        
        // Join via service
        try await groupWorkoutService.updateParticipantStatus(groupWorkout.id, status: .active)
        
        // Start workout session
        try await startGroupWorkout(groupWorkout, asHost: false)
    }
    
    /// Stop the current group workout
    func stopGroupWorkout() async throws {
        FameFitLogger.info("🏋️ Stopping group workout", category: FameFitLogger.workout)
        
        guard isInGroupWorkout else { return }
        
        // Stop metric updates
        stopMetricUpdates()
        
        // Save final metrics to CloudKit
        if let participation = currentParticipation {
            var finalData = participation.workoutData ?? GroupWorkoutData(
                startTime: workoutStartTime ?? Date(),
                endTime: Date(),
                totalEnergyBurned: activeEnergy,
                totalDistance: distance,
                averageHeartRate: averageHeartRate,
                currentHeartRate: heartRate,
                lastUpdated: Date()
            )
            finalData.endTime = Date()
            
            try await groupWorkoutService.updateParticipantData(
                groupWorkoutID ?? "",
                data: finalData
            )
        }
        
        // Complete CloudKit workout if host
        if isHost, let workoutId = groupWorkoutID {
            _ = try await groupWorkoutService.completeGroupWorkout(workoutId)
        } else if let workoutId = groupWorkoutID {
            try await groupWorkoutService.updateParticipantStatus(workoutId, status: .completed)
        }
        
        // Clear cached data if successfully synced
        if syncStatus == .synced {
            await offlineCache.clear()
        }
        
        // Clear stored metadata
        UserDefaults.standard.removeObject(forKey: "activeGroupWorkoutID")
        UserDefaults.standard.removeObject(forKey: "activeGroupWorkoutStartTime")
        
        // Reset state
        resetState()
    }
    
    /// Leave a group workout early
    func leaveGroupWorkout() async throws {
        FameFitLogger.info("🏋️ Leaving group workout early", category: FameFitLogger.workout)
        
        guard isInGroupWorkout else { return }
        
        // Update status to dropped
        if let workoutId = groupWorkoutID {
            try await groupWorkoutService.updateParticipantStatus(workoutId, status: .dropped)
        }
        
        // Stop the workout
        try await stopGroupWorkout()
    }
    
    /// Update metrics from external source (Watch, HealthKit, etc)
    func updateMetrics(heartRate: Double? = nil, calories: Double? = nil, distance: Double? = nil, avgHeartRate: Double? = nil) {
        if let hr = heartRate {
            self.heartRate = hr
        }
        if let cal = calories {
            self.activeEnergy = cal
        }
        if let dist = distance {
            self.distance = dist
        }
        if let avgHR = avgHeartRate {
            self.averageHeartRate = avgHR
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe group workout updates
        groupWorkoutService.workoutUpdates
            .sink { [weak self] update in
                Task { @MainActor [weak self] in
                    await self?.handleGroupWorkoutUpdate(update)
                }
            }
            .store(in: &cancellables)
        
        // Setup Watch connectivity if on iOS
        #if os(iOS)
        setupWatchConnectivity()
        #endif
    }
    
    private func checkForExistingSession() {
        Task { @MainActor in
            // Check for cached offline data
            if await offlineCache.hasPendingData() {
                await syncOfflineData()
            }
            
            // Check for stored group workout session
            if let storedID = UserDefaults.standard.string(forKey: "activeGroupWorkoutID") {
                await attemptReconnection(with: storedID)
            }
        }
    }
    
    private func attemptReconnection(with workoutId: String? = nil) async {
        FameFitLogger.info("🔄 Attempting to reconnect to existing workout session", category: FameFitLogger.workout)
        
        reconnectionAttempts += 1
        
        guard reconnectionAttempts <= maxReconnectionAttempts else {
            FameFitLogger.warning("❌ Max reconnection attempts reached", category: FameFitLogger.workout)
            connectionState = .failed
            return
        }
        
        connectionState = .reconnecting
        
        // Try to recover group workout ID
        let recoveredID = workoutId ?? UserDefaults.standard.string(forKey: "activeGroupWorkoutID")
        
        if let recoveredID = recoveredID {
            do {
                let workout = try await groupWorkoutService.fetchWorkout(recoveredID)
                
                if workout.status == .active {
                    // Rejoin the workout
                    currentGroupWorkout = workout
                    groupWorkoutID = recoveredID
                    isInGroupWorkout = true
                    connectionState = .connected
                    
                    // Resume metric updates
                    startMetricUpdates()
                    
                    FameFitLogger.info("✅ Successfully reconnected to group workout", category: FameFitLogger.workout)
                } else {
                    // Workout ended while disconnected
                    try await stopGroupWorkout()
                }
            } catch {
                FameFitLogger.error("Failed to reconnect", error: error, category: FameFitLogger.workout)
                connectionState = .failed
            }
        }
    }
    
    private func startMetricUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.syncMetricsToCloudKit()
                await self?.fetchParticipantMetrics()
                self?.calculateAggregateMetrics()
            }
        }
    }
    
    private func stopMetricUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func syncMetricsToCloudKit() async {
        guard let workoutId = groupWorkoutID,
              var participation = currentParticipation else { return }
        
        // Update workout data
        let workoutData = GroupWorkoutData(
            startTime: workoutStartTime ?? Date(),
            endTime: nil,
            totalEnergyBurned: activeEnergy,
            totalDistance: distance,
            averageHeartRate: averageHeartRate,
            currentHeartRate: heartRate,
            lastUpdated: Date()
        )
        
        participation.workoutData = workoutData
        
        do {
            syncStatus = .syncing
            try await groupWorkoutService.updateParticipantData(workoutId, data: workoutData)
            syncStatus = .synced
            
            // Clear offline cache on successful sync
            await offlineCache.clearMetrics(for: workoutId)
        } catch {
            syncStatus = .failed
            FameFitLogger.warning("Failed to sync metrics, caching offline", category: FameFitLogger.workout)
            
            // Cache for offline sync
            await offlineCache.saveMetrics(workoutData, for: workoutId)
        }
    }
    
    private func fetchParticipantMetrics() async {
        guard let workoutId = groupWorkoutID else { return }
        
        do {
            let participants = try await groupWorkoutService.getParticipants(workoutId)
            
            var metrics: [String: GroupWorkoutData] = [:]
            for participant in participants where participant.status == .active {
                if let data = participant.workoutData {
                    metrics[participant.userId] = data
                }
            }
            
            participantMetrics = metrics
        } catch {
            FameFitLogger.warning("Failed to fetch participant metrics", category: FameFitLogger.workout)
        }
    }
    
    private func calculateAggregateMetrics() {
        guard !participantMetrics.isEmpty else {
            aggregateMetrics = nil
            return
        }
        
        let totalCalories = participantMetrics.values.reduce(0) { $0 + $1.totalEnergyBurned }
        let totalDistance = participantMetrics.values.reduce(0) { $0 + ($1.totalDistance ?? 0) }
        let avgHeartRate = participantMetrics.values.compactMap { $0.averageHeartRate }.reduce(0, +) / Double(participantMetrics.count)
        
        aggregateMetrics = AggregateWorkoutMetrics(
            participantCount: participantMetrics.count,
            totalCaloriesBurned: totalCalories,
            totalDistance: totalDistance,
            averageHeartRate: avgHeartRate,
            topPerformer: findTopPerformer()
        )
    }
    
    private func findTopPerformer() -> String? {
        participantMetrics.max { $0.value.totalEnergyBurned < $1.value.totalEnergyBurned }?.key
    }
    
    private func handleGroupWorkoutUpdate(_ update: GroupWorkoutUpdate) async {
        switch update {
        case .statusChanged(let workoutId, let status):
            if workoutId == groupWorkoutID {
                switch status {
                case .completed, .cancelled:
                    // Host ended the workout
                    if !isHost {
                        try? await stopGroupWorkout()
                    }
                default:
                    break
                }
            }
            
        case .participantJoined(let workoutId, _):
            if workoutId == groupWorkoutID {
                await fetchParticipantMetrics()
            }
            
        case .participantLeft(let workoutId, _):
            if workoutId == groupWorkoutID {
                await fetchParticipantMetrics()
            }
            
        default:
            break
        }
    }
    
    private func syncOfflineData() async {
        FameFitLogger.info("📤 Syncing offline workout data", category: FameFitLogger.workout)
        
        let pendingMetrics = await offlineCache.getAllPendingMetrics()
        
        for (workoutId, metrics) in pendingMetrics {
            for metric in metrics {
                do {
                    try await groupWorkoutService.updateParticipantData(workoutId, data: metric)
                    await offlineCache.clearMetrics(for: workoutId)
                } catch {
                    FameFitLogger.warning("Failed to sync offline metric", category: FameFitLogger.workout)
                }
            }
        }
    }
    
    private func verifyHealthKitAuthorization() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthKitService.requestAuthorization { authorized, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if !authorized {
                    continuation.resume(throwing: GroupWorkoutCoordinatorError.healthKitNotAuthorized)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func resetState() {
        isInGroupWorkout = false
        currentGroupWorkout = nil
        currentParticipation = nil
        participantMetrics = [:]
        aggregateMetrics = nil
        connectionState = .disconnected
        syncStatus = .idle
        healthKitWorkoutID = nil
        groupWorkoutID = nil
        participantID = nil
        workoutStartTime = nil
        isHost = false
        reconnectionAttempts = 0
        heartRate = 0
        activeEnergy = 0
        distance = 0
        averageHeartRate = 0
    }
    
    #if os(iOS)
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
    #endif
}

// MARK: - Watch Connectivity Delegate

#if os(iOS)
extension GroupWorkoutCoordinator: WCSessionDelegate {
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            connectionState = .disconnected
        }
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            connectionState = .disconnected
        }
    }
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if activationState == .activated {
                connectionState = .connected
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle real-time metric updates from Watch
        if let metrics = message["metrics"] as? [String: Any] {
            Task { @MainActor in
                handleWatchMetricsUpdate(metrics)
            }
        }
    }
    
    @MainActor
    private func handleWatchMetricsUpdate(_ metrics: [String: Any]) {
        // Update local metrics from Watch
        if let heartRate = metrics["heartRate"] as? Double {
            self.heartRate = heartRate
        }
        if let calories = metrics["activeEnergy"] as? Double {
            self.activeEnergy = calories
        }
        if let distance = metrics["distance"] as? Double {
            self.distance = distance
        }
        if let avgHR = metrics["averageHeartRate"] as? Double {
            self.averageHeartRate = avgHR
        }
    }
}
#endif

// MARK: - Supporting Types

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}

enum SyncStatus {
    case idle
    case syncing
    case synced
    case failed
}

struct AggregateWorkoutMetrics {
    let participantCount: Int
    let totalCaloriesBurned: Double
    let totalDistance: Double
    let averageHeartRate: Double
    let topPerformer: String?
}

enum GroupWorkoutCoordinatorError: LocalizedError {
    case healthKitNotAuthorized
    case existingWorkoutActive
    case connectionFailed
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAuthorized:
            "HealthKit authorization required for group workouts"
        case .existingWorkoutActive:
            "Please end your current workout before joining a group workout"
        case .connectionFailed:
            "Failed to connect to group workout"
        case .syncFailed:
            "Failed to sync workout data"
        }
    }
}

// MARK: - Offline Cache

actor GroupWorkoutOfflineCache {
    private var pendingMetrics: [String: [GroupWorkoutData]] = [:]
    private let cacheKey = "GroupWorkoutOfflineCache"
    
    func saveMetrics(_ data: GroupWorkoutData, for workoutId: String) {
        if pendingMetrics[workoutId] == nil {
            pendingMetrics[workoutId] = []
        }
        pendingMetrics[workoutId]?.append(data)
        persistCache()
    }
    
    func getAllPendingMetrics() -> [String: [GroupWorkoutData]] {
        return pendingMetrics
    }
    
    func clearMetrics(for workoutId: String) {
        pendingMetrics[workoutId] = nil
        persistCache()
    }
    
    func clear() {
        pendingMetrics = [:]
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
    
    func hasPendingData() -> Bool {
        loadCache()
        return !pendingMetrics.isEmpty
    }
    
    private func persistCache() {
        if let encoded = try? JSONEncoder().encode(pendingMetrics) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([String: [GroupWorkoutData]].self, from: data) {
            pendingMetrics = decoded
        }
    }
}