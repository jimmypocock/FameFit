# FameFit Watch ↔️ iOS Sync Implementation Roadmap

Last Updated: 2025-08-26

## 🎯 Executive Summary

This document outlines the implementation tasks required to ensure reliable synchronization between the FameFit iOS and Watch apps when distributed via TestFlight. The goal is to achieve seamless data sync, real-time workout coordination, and consistent user experience across both platforms.

## 📊 Current Sync Status

### ✅ What's Already Working

#### Infrastructure
- **WatchConnectivity Framework**: Session setup and activation
- **HealthKit Integration**: Both apps can read/write workout data
- **CloudKit**: Shared container for data persistence
- **Data Models**: Shared between iOS and Watch targets

#### Basic Communication
- `WCSession` delegate implementation on both sides
- Application context updates for user data
- Message passing infrastructure exists
- Reachability checking implemented

### ⚠️ Known Issues & Gaps

#### Critical Issues
1. **Session Activation**: Watch app not always detected when installed via Xcode
2. **Data Consistency**: Profile data may become out of sync
3. **Workout Sync**: Completed workouts don't always appear on iPhone
4. **Background Sync**: Silent sync not working reliably
5. **Group Workouts**: No real-time coordination implemented

#### Missing Features
- Automatic workout start from iPhone
- Real-time group workout sync
- Achievement sync to Watch
- Offline workout queue
- Conflict resolution strategy

## 🚀 Implementation Phases

### Phase 0: Foundation & Testing Setup (3 days) - DO THIS FIRST

#### 0.1 Implement Robust Connection Management

```swift
// Shared/Services/WatchConnectivityManager.swift
import WatchConnectivity

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published private(set) var isReachable = false
    @Published private(set) var isInstalled = false
    @Published private(set) var isPaired = false
    @Published private(set) var connectionState: ConnectionState = .notConfigured
    
    enum ConnectionState {
        case notConfigured
        case notPaired
        case notInstalled
        case inactive
        case active
        case unreachable
    }
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    override init() {
        super.init()
        setupSession()
        startConnectivityChecks()
    }
    
    private func setupSession() {
        guard let session = session else { return }
        session.delegate = self
        session.activate()
    }
    
    private func startConnectivityChecks() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                self.updateConnectionState()
                self.performBackgroundSync()
            }
        }
    }
    
    private func updateConnectionState() {
        guard let session = session else {
            connectionState = .notConfigured
            return
        }
        
        #if os(iOS)
        isPaired = session.isPaired
        isInstalled = session.isWatchAppInstalled
        
        if !isPaired {
            connectionState = .notPaired
        } else if !isInstalled {
            connectionState = .notInstalled
        } else if session.activationState != .activated {
            connectionState = .inactive
        } else if !session.isReachable {
            connectionState = .unreachable
        } else {
            connectionState = .active
        }
        #else
        connectionState = session.activationState == .activated ? .active : .inactive
        #endif
        
        isReachable = session.isReachable
    }
}
```

#### 0.2 Create Sync Coordinator

```swift
// Shared/Services/SyncCoordinator.swift
actor SyncCoordinator {
    private let watchConnectivity: WatchConnectivityManager
    private let cloudKitManager: CloudKitManager
    private let healthKitService: HealthKitService
    
    private var pendingSyncItems: [SyncItem] = []
    private var isSyncing = false
    
    struct SyncItem {
        enum SyncType {
            case userProfile
            case workout(id: String)
            case achievement(id: String)
            case groupWorkout(id: String)
        }
        
        let id = UUID()
        let type: SyncType
        let timestamp: Date
        let retryCount: Int = 0
        let priority: SyncPriority
    }
    
    enum SyncPriority: Int {
        case low = 0
        case medium = 1
        case high = 2
        case critical = 3
    }
    
    func queueSync(_ item: SyncItem) async {
        pendingSyncItems.append(item)
        pendingSyncItems.sort { $0.priority.rawValue > $1.priority.rawValue }
        
        if !isSyncing {
            await processSyncQueue()
        }
    }
    
    private func processSyncQueue() async {
        guard !pendingSyncItems.isEmpty else { return }
        isSyncing = true
        
        while let item = pendingSyncItems.first {
            do {
                try await syncItem(item)
                pendingSyncItems.removeFirst()
            } catch {
                // Handle retry logic with exponential backoff
                if item.retryCount < 3 {
                    var retryItem = item
                    retryItem.retryCount += 1
                    let delay = pow(2.0, Double(retryItem.retryCount))
                    
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        await queueSync(retryItem)
                    }
                }
                pendingSyncItems.removeFirst()
            }
        }
        
        isSyncing = false
    }
    
    private func syncItem(_ item: SyncItem) async throws {
        switch item.type {
        case .userProfile:
            try await syncUserProfile()
        case .workout(let id):
            try await syncWorkout(id: id)
        case .achievement(let id):
            try await syncAchievement(id: id)
        case .groupWorkout(let id):
            try await syncGroupWorkout(id: id)
        }
    }
}
```

#### 0.3 Implement TestFlight Detection

```swift
// Shared/Utilities/EnvironmentDetector.swift
struct EnvironmentDetector {
    static var isTestFlight: Bool {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        return appStoreReceiptURL.lastPathComponent == "sandboxReceipt"
    }
    
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var isAppStore: Bool {
        !isDebug && !isTestFlight
    }
    
    static var shouldUseWatchConnectivity: Bool {
        // Use WatchConnectivity in TestFlight and App Store
        // May have issues in Xcode debug builds
        isTestFlight || isAppStore
    }
}
```

### Phase 1: User Profile Sync (1 week)

#### 1.1 Profile Data Sync Manager

```swift
// Shared/Services/ProfileSyncManager.swift
@MainActor
final class ProfileSyncManager: ObservableObject {
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: Error?
    
    enum SyncState {
        case idle
        case syncing
        case success
        case failed(Error)
    }
    
    private let syncCoordinator: SyncCoordinator
    private let userService: UserProfileService
    
    // iPhone → Watch sync
    func syncProfileToWatch() async {
        guard EnvironmentDetector.shouldUseWatchConnectivity else {
            // Fallback to CloudKit for Xcode builds
            await syncViaCloudKit()
            return
        }
        
        syncState = .syncing
        
        do {
            let profile = try await userService.getCurrentUserProfile()
            
            let profileData: [String: Any] = [
                "userId": profile.id,
                "username": profile.username,
                "displayName": profile.displayName,
                "totalXP": profile.totalXP,
                "workoutCount": profile.workoutCount,
                "currentStreak": profile.currentStreak,
                "lastWorkoutDate": profile.lastWorkoutDate?.timeIntervalSince1970 ?? 0,
                "syncTimestamp": Date().timeIntervalSince1970
            ]
            
            // Send via multiple channels for redundancy
            
            // 1. Application Context (persistent)
            try WatchConnectivityManager.shared.updateApplicationContext(profileData)
            
            // 2. User Info Transfer (guaranteed delivery)
            WatchConnectivityManager.shared.transferUserInfo(profileData)
            
            // 3. Interactive message (if reachable)
            if WatchConnectivityManager.shared.isReachable {
                try await WatchConnectivityManager.shared.sendMessage(profileData)
            }
            
            lastSyncDate = Date()
            syncState = .success
            
        } catch {
            syncError = error
            syncState = .failed(error)
            
            // Queue for retry
            await syncCoordinator.queueSync(
                SyncItem(type: .userProfile, timestamp: Date(), priority: .high)
            )
        }
    }
    
    // Watch → iPhone sync
    func receiveProfileUpdate(_ data: [String: Any]) {
        guard let userId = data["userId"] as? String,
              userId == userService.currentUserId else { return }
        
        Task {
            await userService.updateLocalProfile(from: data)
            lastSyncDate = Date()
            syncState = .success
        }
    }
}
```

#### 1.2 Auto-Sync Triggers

```swift
// iOS App: FameFit/FameFitApp.swift
@main
struct FameFitApp: App {
    @StateObject private var profileSync = ProfileSyncManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { phase in
                    handleScenePhaseChange(phase)
                }
                .onReceive(Timer.publish(every: 300, on: .main, in: .common).autoconnect()) { _ in
                    Task {
                        await profileSync.syncProfileToWatch()
                    }
                }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task {
                await profileSync.syncProfileToWatch()
            }
        case .inactive:
            // Save any pending changes
            break
        case .background:
            // Schedule background sync
            scheduleBackgroundSync()
        @unknown default:
            break
        }
    }
}
```

### Phase 2: Workout Sync (1.5 weeks)

#### 2.1 Workout Start Command (iPhone → Watch)

```swift
// iOS: Services/WatchWorkoutController.swift
@MainActor
final class WatchWorkoutController: ObservableObject {
    @Published var isStartingWorkout = false
    @Published var workoutStartError: Error?
    
    func startWorkoutOnWatch(
        type: HKWorkoutActivityType,
        groupId: String? = nil
    ) async {
        isStartingWorkout = true
        defer { isStartingWorkout = false }
        
        let workoutData: [String: Any] = [
            "command": "startWorkout",
            "workoutType": type.rawValue,
            "groupId": groupId ?? "",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            if WatchConnectivityManager.shared.isReachable {
                // Send immediate message
                let response = try await WatchConnectivityManager.shared.sendMessage(
                    workoutData,
                    replyHandler: { reply in
                        if let started = reply["started"] as? Bool, started {
                            // Workout started successfully
                        }
                    }
                )
            } else {
                // Queue for when Watch becomes reachable
                WatchConnectivityManager.shared.transferUserInfo(workoutData)
                
                throw WatchSyncError.watchNotReachable
            }
        } catch {
            workoutStartError = error
        }
    }
}

// Watch: Services/WorkoutCommandReceiver.swift
final class WorkoutCommandReceiver {
    func handleWorkoutCommand(_ message: [String: Any]) {
        guard let command = message["command"] as? String,
              command == "startWorkout",
              let workoutTypeRaw = message["workoutType"] as? UInt else { return }
        
        let workoutType = HKWorkoutActivityType(rawValue: workoutTypeRaw) ?? .other
        
        Task { @MainActor in
            // Trigger haptic feedback
            WKInterfaceDevice.current().play(.notification)
            
            // Navigate to workout view
            WorkoutManager.shared.startWorkout(type: workoutType)
            
            // Send confirmation back
            WatchConnectivityManager.shared.sendMessage(
                ["started": true, "workoutType": workoutTypeRaw],
                replyHandler: nil
            )
        }
    }
}
```

#### 2.2 Workout Completion Sync (Watch → iPhone)

```swift
// Watch: Services/WorkoutSyncService.swift
actor WorkoutSyncService {
    private let healthKitService: HealthKitService
    private let syncCoordinator: SyncCoordinator
    
    func syncCompletedWorkout(_ workout: HKWorkout) async {
        // Extract workout data
        let workoutData = WorkoutData(
            id: workout.uuid.uuidString,
            type: workout.workoutActivityType,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
            totalDistance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0,
            averageHeartRate: await getAverageHeartRate(for: workout)
        )
        
        // Calculate XP earned
        let xpEarned = XPCalculator.calculate(for: workoutData)
        
        // Prepare sync payload
        let syncPayload: [String: Any] = [
            "workout": workoutData.toDictionary(),
            "xpEarned": xpEarned,
            "syncTimestamp": Date().timeIntervalSince1970,
            "source": "watch"
        ]
        
        // Try immediate sync if iPhone reachable
        if WatchConnectivityManager.shared.isReachable {
            do {
                try await WatchConnectivityManager.shared.sendMessage(syncPayload)
            } catch {
                // Fall back to queued sync
                await queueWorkoutSync(workoutData)
            }
        } else {
            await queueWorkoutSync(workoutData)
        }
        
        // Always save to HealthKit as backup
        await saveToHealthKit(workout)
    }
    
    private func queueWorkoutSync(_ workout: WorkoutData) async {
        await syncCoordinator.queueSync(
            SyncItem(
                type: .workout(id: workout.id),
                timestamp: Date(),
                priority: .critical
            )
        )
    }
}
```

### Phase 3: Group Workout Coordination (2 weeks)

#### 3.1 Real-Time Group Workout Sync

```swift
// Shared/Services/GroupWorkoutCoordinator.swift
actor GroupWorkoutCoordinator {
    private var activeSession: GroupWorkoutSession?
    private var participants: [String: ParticipantStatus] = [:]
    private var metricsUpdateTimer: Timer?
    
    struct GroupWorkoutSession {
        let id: String
        let hostId: String
        let workoutType: HKWorkoutActivityType
        let startTime: Date
        var participants: [String]
        var status: SessionStatus
    }
    
    struct ParticipantStatus {
        let userId: String
        var isActive: Bool
        var currentMetrics: WorkoutMetrics
        var lastUpdate: Date
    }
    
    enum SessionStatus {
        case waiting
        case active
        case paused
        case completed
        case cancelled
    }
    
    // Host creates group workout
    func createGroupWorkout(
        type: HKWorkoutActivityType,
        invitedUsers: [String]
    ) async throws -> GroupWorkoutSession {
        let session = GroupWorkoutSession(
            id: UUID().uuidString,
            hostId: getCurrentUserId(),
            workoutType: type,
            startTime: Date().addingTimeInterval(60), // Start in 1 minute
            participants: invitedUsers + [getCurrentUserId()],
            status: .waiting
        )
        
        activeSession = session
        
        // Notify all participants
        for userId in invitedUsers {
            await sendGroupWorkoutInvite(to: userId, session: session)
        }
        
        // Schedule session start
        scheduleSessionStart(session)
        
        return session
    }
    
    // Sync metrics during workout
    func startMetricsSync() {
        metricsUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true
        ) { _ in
            Task {
                await self.broadcastMetrics()
            }
        }
    }
    
    private func broadcastMetrics() async {
        guard let session = activeSession,
              session.status == .active else { return }
        
        let currentMetrics = await WorkoutManager.shared.getCurrentMetrics()
        
        let metricsData: [String: Any] = [
            "command": "groupWorkoutMetrics",
            "sessionId": session.id,
            "userId": getCurrentUserId(),
            "metrics": currentMetrics.toDictionary(),
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Broadcast to all participants
        if WatchConnectivityManager.shared.isReachable {
            WatchConnectivityManager.shared.sendMessage(metricsData, replyHandler: nil)
        }
        
        // Also sync via CloudKit for redundancy
        await CloudKitGroupWorkoutService.shared.updateMetrics(metricsData)
    }
}
```

### Phase 4: Background & Offline Sync (1 week)

#### 4.1 Background Sync Task

```swift
// iOS: Services/BackgroundSyncManager.swift
import BackgroundTasks

final class BackgroundSyncManager {
    static let syncTaskIdentifier = "com.jimmypocock.FameFit.sync"
    
    static func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: syncTaskIdentifier,
            using: nil
        ) { task in
            handleBackgroundSync(task: task as! BGProcessingTask)
        }
    }
    
    static func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: syncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 1 minute
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background sync: \(error)")
        }
    }
    
    private static func handleBackgroundSync(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                // Sync profile
                await ProfileSyncManager.shared.syncProfileToWatch()
                
                // Sync pending workouts
                await WorkoutSyncService.shared.syncPendingWorkouts()
                
                // Sync achievements
                await AchievementSyncService.shared.syncPendingAchievements()
                
                task.setTaskCompleted(success: true)
                
                // Schedule next sync
                scheduleBackgroundSync()
                
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }
}
```

#### 4.2 Offline Queue Management

```swift
// Shared/Services/OfflineSyncQueue.swift
actor OfflineSyncQueue {
    private var queue: [SyncItem] = []
    private let maxQueueSize = 100
    private let storageKey = "offline_sync_queue"
    
    init() {
        await loadPersistedQueue()
    }
    
    func enqueue(_ item: SyncItem) async {
        queue.append(item)
        
        // Maintain queue size limit
        if queue.count > maxQueueSize {
            queue.removeFirst()
        }
        
        await persistQueue()
    }
    
    func processQueue() async throws {
        guard !queue.isEmpty else { return }
        
        let itemsToProcess = queue
        queue.removeAll()
        
        for item in itemsToProcess {
            do {
                try await processItem(item)
            } catch {
                // Re-queue failed items
                if item.retryCount < 3 {
                    var retryItem = item
                    retryItem.retryCount += 1
                    await enqueue(retryItem)
                }
            }
        }
        
        await persistQueue()
    }
    
    private func persistQueue() async {
        guard let encoded = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
    
    private func loadPersistedQueue() async {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SyncItem].self, from: data) else {
            return
        }
        queue = decoded
    }
}
```

## 🧪 Testing Strategy

### Unit Tests

```swift
// Tests/WatchConnectivityTests.swift
final class WatchConnectivityTests: XCTestCase {
    func testProfileSyncPayload() async throws {
        // Test profile data serialization
        let profile = MockUserProfile()
        let payload = ProfileSyncManager.createSyncPayload(from: profile)
        
        XCTAssertNotNil(payload["userId"])
        XCTAssertNotNil(payload["totalXP"])
        XCTAssertNotNil(payload["syncTimestamp"])
    }
    
    func testOfflineQueuePersistence() async throws {
        // Test queue survives app termination
        let queue = OfflineSyncQueue()
        let testItem = SyncItem(type: .workout(id: "test"), timestamp: Date(), priority: .high)
        
        await queue.enqueue(testItem)
        
        // Simulate app restart
        let newQueue = OfflineSyncQueue()
        let items = await newQueue.getQueuedItems()
        
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, testItem.id)
    }
}
```

### Integration Tests

```swift
// Tests/SyncIntegrationTests.swift
final class SyncIntegrationTests: XCTestCase {
    func testEndToEndWorkoutSync() async throws {
        // Start workout on Watch
        let workout = MockWorkout()
        await WorkoutManager.shared.completeWorkout(workout)
        
        // Wait for sync
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Verify on iPhone
        let syncedWorkouts = await WorkoutService.shared.getRecentWorkouts()
        XCTAssertTrue(syncedWorkouts.contains { $0.id == workout.id })
    }
}
```

## 📈 Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Profile Sync Latency | <5 seconds | Timer from trigger to completion |
| Workout Sync Success Rate | >95% | Successful syncs / total attempts |
| Offline Sync Recovery | 100% | Queued items eventually synced |
| Group Workout Coordination | <1 second delay | Metrics update latency |
| Background Sync Frequency | Every 5 minutes | Background task execution logs |

## 🔍 Verification Checklist

### Pre-TestFlight Checklist
- [ ] Profile syncs within 5 seconds when both apps active
- [ ] Workouts appear within 30 seconds of completion
- [ ] Offline workouts sync when connection restored
- [ ] Group workouts coordinate properly
- [ ] Background sync works when app backgrounded
- [ ] No duplicate data after sync
- [ ] XP calculations match between devices

### TestFlight Testing Checklist
- [ ] Fresh install sync works
- [ ] Existing user upgrade maintains data
- [ ] Watch app detected properly
- [ ] All sync scenarios work as expected
- [ ] Error recovery works properly
- [ ] Performance meets targets
- [ ] No data loss under any condition

## 🚨 Common Issues & Solutions

### Issue: Watch App Not Detected
```swift
// Add fallback detection
if !WCSession.default.isWatchAppInstalled {
    // Check for recent Watch data in HealthKit
    let hasRecentWatchData = await healthKitService.hasRecentWatchWorkouts()
    if hasRecentWatchData {
        // Assume Watch app is installed
        // Use CloudKit for sync instead
    }
}
```

### Issue: Sync Delays
```swift
// Implement priority queue
enum SyncPriority {
    case critical  // Immediate sync required
    case high      // Sync within 30 seconds
    case medium    // Sync within 5 minutes
    case low       // Sync when convenient
}
```

## 🚀 Implementation Timeline

### Week 1
- [ ] Foundation & testing setup
- [ ] Connection management
- [ ] Sync coordinator

### Week 2
- [ ] Profile sync implementation
- [ ] Auto-sync triggers
- [ ] Testing framework

### Week 3-4
- [ ] Workout sync (start & complete)
- [ ] Offline queue
- [ ] Error recovery

### Week 5-6
- [ ] Group workout coordination
- [ ] Real-time metrics sync
- [ ] CloudKit fallback

### Week 7
- [ ] Background sync
- [ ] Performance optimization
- [ ] TestFlight testing

## 📝 Notes

1. **TestFlight vs Xcode**: Always test with TestFlight builds for accurate sync behavior
2. **Redundancy**: Use multiple sync channels (WatchConnectivity + CloudKit + HealthKit)
3. **Error Recovery**: Every sync operation must have retry logic
4. **Performance**: Batch sync operations when possible
5. **Testing**: Automated tests for all sync scenarios

---

**Remember**: The sync system must be bulletproof. Users expect their workout data to appear instantly and never be lost. Test exhaustively before shipping.