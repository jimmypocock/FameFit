//
//  WorkoutManager.swift
//  FameFit Watch App
//
//  Created by paige on 2021/12/11.
//

import Foundation
import HealthKit
import os.log
#if os(watchOS)
import WatchConnectivity
#endif

/// Information about a group workout
struct GroupWorkoutInfo {
    let id: String
    let name: String
    let isHost: Bool
    let participantCount: Int
}

class WorkoutManager: NSObject, ObservableObject, WorkoutManaging {
    // MARK: - Core Properties

    @Published var selectedWorkout: HKWorkoutActivityType?
    @Published var completedWorkout: HKWorkout? // Published when workout completes

    let healthStore = HKHealthStore()
    @Published var session: HKWorkoutSession?
    #if os(watchOS)
        var builder: HKLiveWorkoutBuilder?
    #else
        var builder: AnyObject?
    #endif
    
    // MARK: - Group Workout Properties
    
    @Published var isGroupWorkout: Bool = false
    @Published var groupWorkoutID: String?
    @Published var groupWorkoutName: String?
    @Published var isGroupWorkoutHost: Bool = false
    @Published var groupParticipantCount: Int = 0
    private var groupWorkoutMetadata: [String: Any] = [:]
    private var metricsUploadTimer: Timer?
    private let metricsUploadInterval: TimeInterval = 30.0 // Upload every 30 seconds to preserve battery
    private var metricsRetryCount = 0
    private let maxRetryAttempts = 3
    private var pendingMetrics: [[String: Any]] = []
    private var unreachableCount = 0
    private let maxUnreachableAttempts = 5

    // MARK: - Workout Control
    
    // Protocol conformance method
    func startWorkout(workoutType: HKWorkoutActivityType) {
        startWorkout(workoutType: workoutType, groupWorkoutInfo: nil)
    }

    func startWorkout(workoutType: HKWorkoutActivityType, groupWorkoutInfo: GroupWorkoutInfo? = nil) {
        // Set group workout properties if provided
        if let groupInfo = groupWorkoutInfo {
            FameFitLogger.info("Starting group workout: \(groupInfo.name) (ID: \(groupInfo.id))", category: FameFitLogger.workout)
            configureGroupWorkout(groupInfo)
        } else {
            // Check for pending group workout from iPhone
            checkForGroupWorkout()
            FameFitLogger.info("Starting workout: \(workoutType)", category: FameFitLogger.workout)
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        
        // Configure workout-specific settings based on activity type
        switch workoutType {
        // Swimming requires specific configuration
        case .swimming:
            configuration.locationType = .indoor
            configuration.swimmingLocationType = .pool
            // Default lap length for standard 25m pool
            configuration.lapLength = HKQuantity(unit: .meter(), doubleValue: 25.0)
            
        // Outdoor activities default
        case .running, .walking, .hiking:
            configuration.locationType = .outdoor
            
        // Cycling can be indoor or outdoor
        case .cycling:
            configuration.locationType = .outdoor // Default to outdoor
            
        // Indoor cycling variants
        case .cycling where groupWorkoutInfo?.name.lowercased().contains("indoor") == true,
             .cycling where groupWorkoutInfo?.name.lowercased().contains("spin") == true:
            configuration.locationType = .indoor
            
        // Gym/Indoor activities
        case .elliptical, .rowing, .stairClimbing, .jumpRope,
             .traditionalStrengthTraining, .functionalStrengthTraining,
             .coreTraining, .highIntensityIntervalTraining, .crossTraining:
            configuration.locationType = .indoor
            
        // Mind & Body (typically indoor)
        case .yoga, .pilates, .taiChi, .mindAndBody, .flexibility, .barre:
            configuration.locationType = .indoor
            
        // Martial Arts (typically indoor)
        case .boxing, .kickboxing, .martialArts:
            configuration.locationType = .indoor
            
        // Dance (typically indoor)
        case .cardioDance, .socialDance:
            configuration.locationType = .indoor
            
        // Sports (context-dependent, default to outdoor)
        case .basketball, .soccer, .tennis, .golf, .baseball,
             .volleyball, .badminton, .pickleball:
            configuration.locationType = .outdoor
            
        // Winter sports (outdoor)
        case .snowboarding, .downhillSkiing, .crossCountrySkiing:
            configuration.locationType = .outdoor
            
        // Water sports (outdoor)
        case .surfingSports, .paddleSports:
            configuration.locationType = .outdoor
            
        // Other outdoor activities
        case .climbing:
            configuration.locationType = .outdoor
            
        // Default for unknown or other
        default:
            configuration.locationType = .unknown
        }

        #if os(watchOS)
            do {
                session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                builder = session?.associatedWorkoutBuilder()

                FameFitLogger.debug("Session and builder created successfully", category: FameFitLogger.workout)
            } catch {
                FameFitLogger.error("Failed to create workout session", error: error, category: FameFitLogger.workout)
                DispatchQueue.main.async {
                    self.isWorkoutRunning = false
                }
                return
            }

            // Set up data source
            guard let builder else {
                FameFitLogger.error("Builder is nil", category: FameFitLogger.workout)
                return
            }

            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Set delegates
            session?.delegate = self
            builder.delegate = self

            // Start the session first
            let startDate = Date()
            session?.startActivity(with: startDate)
            FameFitLogger.debug("Session started", category: FameFitLogger.workout)

            // Begin collection after session starts
            FameFitLogger.debug("About to call beginCollection", category: FameFitLogger.workout)
            builder.beginCollection(withStart: startDate) { [weak self] success, error in
                FameFitLogger.debug(
                    "Begin collection result: \(success), error: \(String(describing: error))",
                    category: FameFitLogger.workout
                )

                DispatchQueue.main.async {
                    if success {
                        self?.isWorkoutRunning = true
                        FameFitLogger.info("Workout is now running", category: FameFitLogger.workout)
                        // Start display timer when collection begins successfully
                        self?.startDisplayTimer()
                    } else {
                        FameFitLogger.error(
                            "Failed to begin collection: \(error?.localizedDescription ?? "Unknown error")",
                            category: FameFitLogger.workout
                        )
                        self?.workoutError = "Failed to start workout: \(error?.localizedDescription ?? "Unknown error")"
                        self?.isWorkoutRunning = false
                    }
                }
            }
        #endif
    }

    // MARK: - Authorization

    func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,          // Display real-time heart rate
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,  // Display calories burned
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!, // Track running/walking distance
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,     // Track cycling distance
            HKQuantityType.quantityType(forIdentifier: .distanceSwimming)!,    // Track swimming distance
            HKObjectType.workoutType()  // Read previous workouts for context
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if !success {
                FameFitLogger.error(
                    "HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")",
                    category: FameFitLogger.workout
                )
            }
        }
    }

    // MARK: - State Control

    // MARK: - Workout State

    @Published var isWorkoutRunning = false
    @Published var isPaused = false
    @Published var workoutError: String?

    // Display timer for smooth UI updates (NOT the actual workout timer)
    // NOT @Published - views that need this should use TimelineView or Timer
    var displayElapsedTime: TimeInterval = 0
    private var displayTimer: Timer?

    private let timeMultiplier: Double = 1.0

    private var lastMilestoneTime: TimeInterval = 0
    private var messageTimer: Timer?


    func pause() {
        session?.pause()
        // State will be updated by HealthKit delegate
        FameFitLogger.debug("Requested workout pause", category: FameFitLogger.workout)
    }

    func resume() {
        session?.resume()
        // State will be updated by HealthKit delegate
        FameFitLogger.debug("Requested workout resume", category: FameFitLogger.workout)
    }

    func togglePause() {
        if isWorkoutRunning {
            pause()
        } else if isPaused {
            resume()
        }
    }

    func endWorkout() {
        FameFitLogger.info("Ending workout", category: FameFitLogger.workout)
        displayTimer?.invalidate()
        
        // Stop metrics upload timer (safe to call even if not group workout)
        stopMetricsUpload()

        guard let session else {
            workoutError = "No active workout to end"
            return
        }
        
        // Check if session is already ending/ended
        if session.state == .ended || session.state == .stopped {
            FameFitLogger.warning("Workout already ended/stopped, ignoring duplicate end request", category: FameFitLogger.workout)
            return
        }

        // Show workout-specific end message based on type and duration

        session.end()
        // Summary will be shown by HealthKit delegate when workout ends
    }

    // MARK: - Workout Metrics
    // NOT @Published - these update too frequently and cause performance issues
    // Views should read these directly when needed or use TimelineView
    var averageHeartRate: Double = 0
    var heartRate: Double = 0
    var activeEnergy: Double = 0
    var distance: Double = 0
    @Published var workout: HKWorkout?

    // MARK: - Summary Data

    var averageHeartRateForSummary: Double { averageHeartRate }
    var totalCaloriesForSummary: Double { activeEnergy }
    var totalDistanceForSummary: Double { distance }
    var elapsedTimeForSummary: TimeInterval { displayElapsedTime }

    func resetWorkout() {
        FameFitLogger.debug("Resetting workout manager state", category: FameFitLogger.workout)
        selectedWorkout = nil
        builder = nil
        session = nil
        workout = nil
        completedWorkout = nil
        activeEnergy = 0
        averageHeartRate = 0
        heartRate = 0
        distance = 0
        isWorkoutRunning = false
        isPaused = false
        displayElapsedTime = 0
        workoutError = nil
        lastMilestoneTime = 0
        displayTimer?.invalidate()
        displayTimer = nil
        messageTimer?.invalidate()
        messageTimer = nil
        // Reset group workout properties
        isGroupWorkout = false
        groupWorkoutID = nil
        groupWorkoutName = nil
        isGroupWorkoutHost = false
        groupParticipantCount = 0
        groupWorkoutMetadata = [:]
        // Stop metrics upload timer
        stopMetricsUpload()
        // Clear pending metrics
        pendingMetrics.removeAll()
        metricsRetryCount = 0
    }
    
    // MARK: - Group Workout Methods
    
    
    func updateGroupParticipantCount(_ count: Int) {
        groupParticipantCount = count
        groupWorkoutMetadata["participantCount"] = count
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        // Update display at 0.01s for smooth timer display (100Hz)
        // This is just for UI, not for data syncing
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateDisplayTime()
            }
        }
    }

    private func updateDisplayTime() {
        #if os(watchOS)
            if let builderTime = builder?.elapsedTime {
                displayElapsedTime = builderTime * timeMultiplier
            }
        #endif
    }

    private func startMilestoneTimer() {
        messageTimer?.invalidate()
        // Check every 5 seconds (which is 5 minutes in accelerated time)
        messageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMilestones()
        }
    }

    private func checkMilestones() {
        let currentTime = displayElapsedTime

        // Show regular milestone or random message
        if currentTime >= 300, lastMilestoneTime < 300 {
            lastMilestoneTime = 300
        } else if currentTime >= 600, lastMilestoneTime < 600 {
            lastMilestoneTime = 600
        } else if currentTime >= 1_200, lastMilestoneTime < 1_200 {
            lastMilestoneTime = 1_200
        } else if currentTime >= 1_800, lastMilestoneTime < 1_800 {
            lastMilestoneTime = 1_800
        }
    }

    private func getWorkoutName(for workoutType: HKWorkoutActivityType) -> String {
        workoutType.displayName
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        FameFitLogger.debug("Session state changed from \(fromState.rawValue) to \(toState.rawValue)", category: FameFitLogger.workout)
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            switch toState {
            case .running:
                self?.isWorkoutRunning = true
                self?.isPaused = false
                self?.workoutError = nil
                if self?.displayTimer == nil {
                    self?.startDisplayTimer()
                }
                // Start checking for milestones
                self?.startMilestoneTimer()
            case .paused:
                self?.isWorkoutRunning = false
                self?.isPaused = true
                self?.displayTimer?.invalidate()
                self?.displayTimer = nil
                self?.messageTimer?.invalidate()
            case .stopped:
                self?.isWorkoutRunning = false
                self?.isPaused = false
                self?.displayTimer?.invalidate()
                self?.displayTimer = nil
            case .notStarted:
                self?.isWorkoutRunning = false
                self?.isPaused = false
                self?.displayTimer?.invalidate()
                self?.displayTimer = nil
            default:
                break
            }
        }

        // Wait for the session to transition states before ending the builder.
        if toState == .ended {
            // Add group workout metadata if this is a group workout
            #if os(watchOS)
            if let builder = builder, isGroupWorkout, !groupWorkoutMetadata.isEmpty {
                // Add final participant count
                groupWorkoutMetadata["finalParticipantCount"] = groupParticipantCount
                
                // Add metadata to the builder before finishing
                builder.addMetadata(groupWorkoutMetadata) { success, error in
                    if !success {
                        FameFitLogger.warning("Failed to add group workout metadata: \(String(describing: error))", category: FameFitLogger.workout)
                    }
                }
            }
            #endif
            
            // Store references locally to avoid retain issues
            let currentBuilder = builder
            
            currentBuilder?.endCollection(withEnd: date) { [weak self] _, _ in
                currentBuilder?.finishWorkout { [weak self] workout, _ in
                    DispatchQueue.main.async {
                        self?.workout = workout
                        
                        // Publish the completed workout so views can show summary
                        FameFitLogger.debug("📍 WorkoutManager: Setting completedWorkout to \(workout?.uuid.uuidString ?? "nil")", category: FameFitLogger.workout)
                        self?.completedWorkout = workout
                        
                        // Send workout completion to iPhone
                        if let workoutID = workout?.uuid.uuidString {
                            FameFitLogger.info("⌚ Notifying iPhone of workout completion: \(workoutID)", category: FameFitLogger.workout)
                            WatchConnectivityManager.shared.sendWorkoutCompletion(workoutID: workoutID)
                        }
                        
                        // Clean up references immediately
                        // The workout data is already captured in self?.workout
                        self?.session = nil
                        self?.builder = nil
                    }
                }
            }
        }
    }

    func workoutSession(_: HKWorkoutSession, didFailWithError error: Error) {
        FameFitLogger.error("Workout session failed", error: error, category: FameFitLogger.workout)
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

#if os(watchOS)
    extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
        func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}

        func workoutBuilder(
            _ workoutBuilder: HKLiveWorkoutBuilder,
            didCollectDataOf collectedTypes: Set<HKSampleType>
        ) {
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { return }
                let statistics = workoutBuilder.statistics(for: quantityType)

                // Update the published values.
                updateForStatistics(statistics)
            }
        }

        func updateForStatistics(_ statistics: HKStatistics?) {
            guard let statistics else {
                return
            }

            DispatchQueue.main.async {
                switch statistics.quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    self.heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                    self.averageHeartRate = statistics.averageQuantity()?.doubleValue(for: heartRateUnit) ?? 0

                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    let energyUnit = HKUnit.kilocalorie()
                    self.activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0

                case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
                     HKQuantityType.quantityType(forIdentifier: .distanceCycling):
                    let meterUnit = HKUnit.meter()
                    self.distance = statistics.sumQuantity()?.doubleValue(for: meterUnit) ?? 0

                default: return
                }
            }
        }
    }
#endif

// MARK: - Group Workout Methods

extension WorkoutManager {
    /// Configure workout manager for a group workout
    private func configureGroupWorkout(_ info: GroupWorkoutInfo) {
        isGroupWorkout = true
        groupWorkoutID = info.id
        groupWorkoutName = info.name
        isGroupWorkoutHost = info.isHost
        groupParticipantCount = info.participantCount
        
        // Prepare metadata for HealthKit
        groupWorkoutMetadata = [
            "groupWorkoutID": info.id,
            "groupWorkoutName": info.name,
            "isGroupWorkout": true,
            "isHost": info.isHost,
            "participantCount": info.participantCount
        ]
        
        // Start metrics upload timer
        startMetricsUpload()
    }
    
    private func checkForGroupWorkout() {
        // Check if there's pending group workout info from iPhone
        if let workoutID = UserDefaults.standard.string(forKey: "pendingGroupWorkoutID"),
           let workoutName = UserDefaults.standard.string(forKey: "pendingGroupWorkoutName") {
            
            let isHost = UserDefaults.standard.bool(forKey: "pendingGroupWorkoutIsHost")
            let participantCount = UserDefaults.standard.integer(forKey: "pendingGroupWorkoutParticipantCount")
            
            let groupInfo = GroupWorkoutInfo(
                id: workoutID,
                name: workoutName,
                isHost: isHost,
                participantCount: participantCount > 0 ? participantCount : 1
            )
            
            // Clear the pending info
            UserDefaults.standard.removeObject(forKey: "pendingGroupWorkoutID")
            UserDefaults.standard.removeObject(forKey: "pendingGroupWorkoutName")
            UserDefaults.standard.removeObject(forKey: "pendingGroupWorkoutIsHost")
            UserDefaults.standard.removeObject(forKey: "pendingGroupWorkoutParticipantCount")
            
            // Configure for group workout
            configureGroupWorkout(groupInfo)
            
            FameFitLogger.info("🏋️ Restored group workout: \(workoutName) (Host: \(isHost))", category: FameFitLogger.workout)
        }
    }
    
    private func startMetricsUpload() {
        guard isGroupWorkout else { return }
        
        // Start timer to upload metrics every 5 seconds
        metricsUploadTimer = Timer.scheduledTimer(withTimeInterval: metricsUploadInterval, repeats: true) { [weak self] _ in
            self?.uploadMetrics()
        }
    }
    
    private func uploadMetrics() {
        guard isGroupWorkout,
              let workoutID = groupWorkoutID else { return }
        
        // Prepare metrics
        let metrics: [String: Any] = [
            "workoutID": workoutID,
            "timestamp": Date(),
            "heartRate": self.heartRate,
            "activeEnergy": self.activeEnergy,
            "distance": self.distance,
            "elapsedTime": self.displayElapsedTime,
            "averageHeartRate": self.averageHeartRate,
            "isActive": self.isWorkoutRunning
        ]
        
        #if os(watchOS)
        // Check if Watch connectivity is available
        if WCSession.default.isReachable {
            unreachableCount = 0 // Reset counter when reachable
            
            // Try to send pending metrics first
            sendPendingMetrics()
            
            // Send current metrics
            WCSession.default.sendMessage([
                "command": "groupWorkoutMetrics",
                "metrics": metrics
            ], replyHandler: { [weak self] response in
                // Success - reset retry count
                self?.metricsRetryCount = 0
                FameFitLogger.debug("✅ Metrics sent successfully", category: FameFitLogger.workout)
            }, errorHandler: { [weak self] error in
                self?.handleMetricsUploadError(metrics: metrics, error: error)
            })
        } else {
            unreachableCount += 1
            
            // If iPhone has been unreachable for too long, stop trying to save battery
            if unreachableCount >= maxUnreachableAttempts {
                FameFitLogger.warning("📱 iPhone unreachable for \(unreachableCount) attempts, pausing group sync to save battery", category: FameFitLogger.workout)
                // Stop the timer to save battery
                stopMetricsUpload()
                // Still save the workout locally
                return
            }
            
            // Queue metrics for later
            queueMetricsForLater(metrics)
            FameFitLogger.debug("📱 Watch not reachable (attempt \(unreachableCount)/\(maxUnreachableAttempts)), queuing metrics", category: FameFitLogger.workout)
        }
        #endif
        
        FameFitLogger.debug("📊 Processing metrics - HR: \(self.heartRate), Energy: \(self.activeEnergy)", category: FameFitLogger.workout)
    }
    
    private func handleMetricsUploadError(metrics: [String: Any], error: Error) {
        metricsRetryCount += 1
        
        if metricsRetryCount < maxRetryAttempts {
            // Retry with exponential backoff
            let delay = Double(metricsRetryCount) * 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.retryMetricsUpload(metrics)
            }
            FameFitLogger.warning("⚠️ Metrics upload failed, retrying in \(delay)s (attempt \(metricsRetryCount)/\(maxRetryAttempts))", category: FameFitLogger.workout)
        } else {
            // Max retries exceeded, queue for later
            queueMetricsForLater(metrics)
            metricsRetryCount = 0
            FameFitLogger.error("❌ Metrics upload failed after \(maxRetryAttempts) attempts, queuing for later", error: error, category: FameFitLogger.workout)
        }
    }
    
    private func retryMetricsUpload(_ metrics: [String: Any]) {
        #if os(watchOS)
        guard WCSession.default.isReachable else {
            queueMetricsForLater(metrics)
            return
        }
        
        WCSession.default.sendMessage([
            "command": "groupWorkoutMetrics",
            "metrics": metrics
        ], replyHandler: { [weak self] _ in
            self?.metricsRetryCount = 0
        }, errorHandler: { [weak self] error in
            self?.handleMetricsUploadError(metrics: metrics, error: error)
        })
        #endif
    }
    
    private func queueMetricsForLater(_ metrics: [String: Any]) {
        pendingMetrics.append(metrics)
        
        // Limit queue size to prevent memory issues
        // Keep only last 10 metrics (5 minutes worth at 30 second intervals)
        if pendingMetrics.count > 10 {
            pendingMetrics.removeFirst()
        }
    }
    
    private func sendPendingMetrics() {
        #if os(watchOS)
        guard !pendingMetrics.isEmpty,
              WCSession.default.isReachable else { return }
        
        let metricsToSend = pendingMetrics
        pendingMetrics.removeAll()
        
        for metrics in metricsToSend {
            WCSession.default.sendMessage([
                "command": "groupWorkoutMetrics",
                "metrics": metrics
            ], replyHandler: nil, errorHandler: { [weak self] error in
                // Re-queue failed metrics
                self?.queueMetricsForLater(metrics)
            })
        }
        #endif
    }
    
    private func stopMetricsUpload() {
        metricsUploadTimer?.invalidate()
        metricsUploadTimer = nil
    }
}
