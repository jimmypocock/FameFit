//
//  GroupWorkoutTestHelper.swift
//  FameFit
//
//  Helper for testing group workouts in various scenarios
//

import Foundation
import HealthKit

/// Helper class for testing group workouts
public final class GroupWorkoutTestHelper {
    
    // MARK: - Testing Scenarios
    
    public enum TestScenario {
        case simulatorOnly       // Both iOS and Watch simulators
        case physicalDevices     // Both physical devices
        case mixedDevices       // Simulator + physical device
        case mockDataOnly       // Full mock mode for UI testing
    }
    
    // MARK: - Public Methods
    
    /// Detect current testing scenario
    public static func detectTestingScenario() -> TestScenario {
        #if targetEnvironment(simulator)
            // Running in simulator
            if ProcessInfo.processInfo.environment["TESTING_WITH_PHYSICAL_WATCH"] == "1" {
                return .mixedDevices
            } else {
                return .simulatorOnly
            }
        #else
            // Running on physical device
            return .physicalDevices
        #endif
    }
    
    /// Configure app for testing scenario
    public static func configureForTesting(_ scenario: TestScenario) {
        switch scenario {
        case .simulatorOnly:
            configureSimulatorTesting()
        case .physicalDevices:
            configurePhysicalDeviceTesting()
        case .mixedDevices:
            configureMixedDeviceTesting()
        case .mockDataOnly:
            configureMockDataTesting()
        }
    }
    
    /// Create a test group workout
    public static func createTestGroupWorkout(
        name: String = "Test Group Workout",
        startTime: Date = Date().addingTimeInterval(300), // 5 minutes from now
        duration: TimeInterval = 1800 // 30 minutes
    ) -> GroupWorkout {
        return GroupWorkout(
            id: UUID().uuidString,
            name: name,
            description: "Test workout for development",
            workoutType: .running,
            hostID: "test-host-id",
            maxParticipants: 10,
            scheduledStart: startTime,
            scheduledEnd: startTime.addingTimeInterval(duration),
            status: .scheduled,
            isPublic: true,
            tags: ["test", "development"]
        )
    }
    
    /// Generate mock workout metrics
    public static func generateMockMetrics(
        participantID: String,
        workoutID: String,
        elapsedTime: TimeInterval
    ) -> WorkoutMetrics {
        // Generate realistic-looking metrics
        let baseHeartRate = 70.0
        let exerciseHeartRate = baseHeartRate + (50.0 * min(elapsedTime / 300, 1.0)) // Ramp up over 5 min
        let variation = Double.random(in: -10...10)
        
        let energyPerSecond = 0.15 // ~540 kcal/hour
        let distancePerSecond = 2.5 // ~9 km/hour
        
        return WorkoutMetrics(
            workoutID: workoutID,
            userID: participantID,
            workoutType: "running",
            groupWorkoutID: workoutID,  // Set groupWorkoutID to indicate group workout
            sharingLevel: .groupOnly,
            heartRate: exerciseHeartRate + variation,
            activeEnergyBurned: energyPerSecond * elapsedTime,
            distance: distancePerSecond * elapsedTime,
            elapsedTime: elapsedTime
        )
    }
    
    // MARK: - Private Configuration Methods
    
    private static func configureSimulatorTesting() {
        print("""
        📱⌚ SIMULATOR TESTING MODE
        ============================
        - Using UserDefaults for Watch-Phone communication
        - Mock HealthKit data will be generated
        - CloudKit sync will work normally
        
        Tips:
        1. Run both iOS and Watch simulators
        2. Use 'Debug > Trigger Group Workout' menu in iOS app
        3. Watch simulator will show mock notification
        """)
        
        // Enable testing flags
        UserDefaults.standard.set(true, forKey: "group_workout_testing_mode")
        UserDefaults.standard.set("simulator", forKey: "testing_scenario")
    }
    
    private static func configurePhysicalDeviceTesting() {
        print("""
        📱⌚ PHYSICAL DEVICE TESTING MODE
        ================================
        - Real WatchConnectivity will be used
        - Real HealthKit data from Watch
        - Full CloudKit sync
        
        Setup:
        1. Ensure iPhone and Watch are paired
        2. Build & Run iOS app on iPhone
        3. Build & Run Watch app on Apple Watch
        4. Both apps should be debuggable in Xcode
        """)
        
        UserDefaults.standard.set(false, forKey: "group_workout_testing_mode")
        UserDefaults.standard.set("physical", forKey: "testing_scenario")
    }
    
    private static func configureMixedDeviceTesting() {
        print("""
        📱⌚ MIXED DEVICE TESTING MODE
        ==============================
        - iOS Simulator + Physical Apple Watch
        - WatchConnectivity works with some limitations
        - Real HealthKit data from Watch
        
        Setup:
        1. Run iOS app in Simulator
        2. Run Watch app on physical Apple Watch
        3. Ensure both are on same WiFi network
        """)
        
        UserDefaults.standard.set(true, forKey: "group_workout_testing_mode")
        UserDefaults.standard.set("mixed", forKey: "testing_scenario")
    }
    
    private static func configureMockDataTesting() {
        print("""
        📱⌚ MOCK DATA TESTING MODE
        ===========================
        - No real device communication
        - All data is mocked
        - Good for UI development
        
        Features:
        - Auto-generates participant data
        - Simulates real-time updates
        - No HealthKit or CloudKit required
        """)
        
        UserDefaults.standard.set(true, forKey: "group_workout_testing_mode")
        UserDefaults.standard.set(true, forKey: "use_mock_data_only")
        UserDefaults.standard.set("mock", forKey: "testing_scenario")
    }
}

// MARK: - Testing Commands

#if DEBUG
public extension GroupWorkoutTestHelper {
    
    /// Trigger a test group workout (for development)
    static func triggerTestGroupWorkout() async {
        print("🧪 Triggering test group workout...")
        
        let workout = createTestGroupWorkout(
            name: "Debug Test Run",
            startTime: Date(), // Start immediately for testing
            duration: 600 // 10 minutes
        )
        
        // Send to Watch based on scenario
        let scenario = detectTestingScenario()
        
        switch scenario {
        case .simulatorOnly, .mockDataOnly:
            // Use UserDefaults to communicate
            if let data = try? JSONEncoder().encode(workout) {
                UserDefaults.standard.set(data, forKey: "test_group_workout")
                NotificationCenter.default.post(
                    name: Notification.Name("TestGroupWorkoutTriggered"),
                    object: workout
                )
            }
            
        case .physicalDevices, .mixedDevices:
            // Use real WatchConnectivity
            try? await EnhancedWatchConnectivityManager.shared.sendGroupWorkoutCommand(
                workoutID: workout.id,
                workoutName: workout.name,
                workoutType: Int(workout.workoutType.rawValue),
                isHost: true
            )
        }
        
        print("✅ Test workout triggered: \(workout.name)")
    }
    
    /// Print current testing configuration
    static func printTestingConfiguration() {
        let scenario = detectTestingScenario()
        print("""
        
        🧪 GROUP WORKOUT TESTING CONFIGURATION
        =====================================
        Scenario: \(scenario)
        Testing Mode: \(UserDefaults.standard.bool(forKey: "group_workout_testing_mode"))
        Mock Data Only: \(UserDefaults.standard.bool(forKey: "use_mock_data_only"))
        
        Watch Connectivity:
        - Session Supported: \(WatchConnectivity.WCSession.isSupported())
        #if os(iOS)
        - Watch Paired: \(WatchConnectivity.WCSession.default.isPaired)
        - Watch App Installed: \(WatchConnectivity.WCSession.default.isWatchAppInstalled)
        #endif
        - Reachable: \(WatchConnectivity.WCSession.default.isReachable)
        
        """)
    }
}
#endif