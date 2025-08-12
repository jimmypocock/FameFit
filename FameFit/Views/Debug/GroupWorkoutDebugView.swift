//
//  GroupWorkoutDebugView.swift
//  FameFit
//
//  Debug menu for testing group workout scenarios
//

#if DEBUG
import SwiftUI
import HealthKit
import WatchConnectivity

struct GroupWorkoutDebugView: View {
    @Environment(\.dependencyContainer) private var container
    @Environment(\.dismiss) private var dismiss
    
    @State private var testScenario: TestScenario = .simulatorOnly
    @State private var isTestingWorkout = false
    @State private var testWorkoutName = "Debug Test Run"
    @State private var testDuration: Double = 30 // minutes
    @State private var testParticipants = 3
    @State private var logMessages: [String] = []
    @State private var watchReachable = false
    @State private var isPaired = false
    @State private var isWatchAppInstalled = false
    
    // Testing Scenarios
    enum TestScenario: String, CaseIterable {
        case simulatorOnly = "Simulator Only"
        case physicalDevices = "Physical Devices"  
        case mixedDevices = "Mixed (Sim + Device)"
        case mockDataOnly = "Mock Data Only"
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Testing Scenario
                Section("Testing Scenario") {
                    Picker("Scenario", selection: $testScenario) {
                        ForEach(TestScenario.allCases, id: \.self) { scenario in
                            Text(scenario.rawValue).tag(scenario)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text(scenarioDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Connection Status
                Section("Connection Status") {
                    HStack {
                        Text("Watch Connection")
                        Spacer()
                        Text(watchReachable ? "Connected" : "Not Connected")
                            .foregroundColor(watchReachable ? .green : .red)
                    }
                    
                    #if os(iOS)
                    HStack {
                        Text("Watch Paired")
                        Spacer()
                        Image(systemName: isPaired ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(isPaired ? .green : .red)
                    }
                    
                    HStack {
                        Text("Watch App Installed")
                        Spacer()
                        Image(systemName: isWatchAppInstalled ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(isWatchAppInstalled ? .green : .red)
                    }
                    #endif
                    
                    Button("Test Connection") {
                        testWatchConnection()
                    }
                }
                
                // Test Workout Configuration
                Section("Test Workout") {
                    TextField("Workout Name", text: $testWorkoutName)
                    
                    HStack {
                        Text("Duration")
                        Slider(value: $testDuration, in: 5...120, step: 5)
                        Text("\(Int(testDuration)) min")
                            .frame(width: 60)
                    }
                    
                    Stepper("Mock Participants: \(testParticipants)", value: $testParticipants, in: 1...10)
                    
                    Button(action: startTestWorkout) {
                        Label("Start Test Workout", systemImage: "play.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isTestingWorkout)
                    
                    if isTestingWorkout {
                        Button(action: stopTestWorkout) {
                            Label("Stop Test", systemImage: "stop.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                
                // Quick Actions
                Section("Quick Actions") {
                    Button("Send Test Command to Watch") {
                        sendTestCommandToWatch()
                    }
                    
                    Button("Generate Mock Metrics") {
                        generateMockMetrics()
                    }
                    
                    Button("Clear Test Data") {
                        clearTestData()
                    }
                }
                
                // Debug Log
                Section("Debug Log") {
                    if logMessages.isEmpty {
                        Text("No messages yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(logMessages.reversed(), id: \.self) { message in
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("🧪 Group Workout Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupDebugEnvironment()
            checkWatchStatus()
        }
    }
    
    // MARK: - Helper Methods
    
    private var scenarioDescription: String {
        switch testScenario {
        case .simulatorOnly:
            return "Both iOS and Watch running in simulators"
        case .physicalDevices:
            return "Both running on physical devices"
        case .mixedDevices:
            return "iOS Simulator + Physical Watch"
        case .mockDataOnly:
            return "UI testing with mock data only"
        }
    }
    
    private func setupDebugEnvironment() {
        addLog("Debug environment configured for: \(testScenario.rawValue)")
        
        // Set testing flags
        UserDefaults.standard.set(true, forKey: "group_workout_testing_mode")
        UserDefaults.standard.set(testScenario.rawValue, forKey: "testing_scenario")
    }
    
    private func checkWatchStatus() {
        if WCSession.isSupported() {
            let session = WCSession.default
            
            #if os(iOS)
            isPaired = session.isPaired
            isWatchAppInstalled = session.isWatchAppInstalled
            #endif
            
            watchReachable = session.isReachable
            addLog("Watch status - Reachable: \(watchReachable)")
        }
    }
    
    private func testWatchConnection() {
        guard WCSession.isSupported() else {
            addLog("❌ WatchConnectivity not supported")
            return
        }
        
        let session = WCSession.default
        
        if session.isReachable {
            let message = ["command": "ping"]
            session.sendMessage(message, replyHandler: { response in
                DispatchQueue.main.async {
                    self.addLog("✅ Watch responded: \(response)")
                }
            }, errorHandler: { error in
                DispatchQueue.main.async {
                    self.addLog("❌ Watch error: \(error.localizedDescription)")
                }
            })
        } else {
            addLog("❌ Watch not reachable")
        }
    }
    
    private func startTestWorkout() {
        isTestingWorkout = true
        addLog("Starting test workout: \(testWorkoutName)")
        
        // Create test workout
        let workout = createTestGroupWorkout()
        
        // Send to Watch or simulate based on scenario
        switch testScenario {
        case .simulatorOnly, .mockDataOnly:
            // Use UserDefaults for simulator communication
            if let data = try? JSONEncoder().encode(workout) {
                UserDefaults.standard.set(data, forKey: "test_group_workout")
                addLog("✅ Test workout saved to UserDefaults")
            }
            
        case .physicalDevices, .mixedDevices:
            // Use real WatchConnectivity
            sendWorkoutToWatch(workout)
        }
    }
    
    private func stopTestWorkout() {
        isTestingWorkout = false
        addLog("Test workout stopped")
    }
    
    private func sendTestCommandToWatch() {
        if testScenario == .simulatorOnly || testScenario == .mockDataOnly {
            // Simulate sending command
            let command = ["command": "startGroupWorkout", "workoutID": UUID().uuidString]
            if let data = try? JSONSerialization.data(withJSONObject: command) {
                UserDefaults.standard.set(data, forKey: "pending_watch_command")
                addLog("✅ Command sent via UserDefaults (simulator)")
            }
        } else {
            // Use real WatchConnectivity
            guard WCSession.isSupported() && WCSession.default.isReachable else {
                addLog("❌ Watch not reachable")
                return
            }
            
            let message: [String: Any] = [
                "command": "startGroupWorkout",
                "workoutID": UUID().uuidString,
                "workoutName": testWorkoutName,
                "workoutType": HKWorkoutActivityType.running.rawValue
            ]
            
            WCSession.default.sendMessage(message, replyHandler: { response in
                DispatchQueue.main.async {
                    self.addLog("✅ Watch acknowledged: \(response)")
                }
            }, errorHandler: { error in
                DispatchQueue.main.async {
                    self.addLog("❌ Error: \(error.localizedDescription)")
                }
            })
        }
    }
    
    private func generateMockMetrics() {
        addLog("Generating mock metrics for \(testParticipants) participants...")
        
        for i in 1...testParticipants {
            let metrics: [String: Any] = [
                "participantID": "TestUser\(i)",
                "heartRate": Double.random(in: 120...180),
                "activeEnergy": Double.random(in: 100...500),
                "distance": Double.random(in: 1000...5000),
                "elapsedTime": Double.random(in: 60...600)
            ]
            
            // Save to UserDefaults for simulator testing
            UserDefaults.standard.set(metrics, forKey: "mock_metrics_\(i)")
        }
        
        addLog("✅ Generated metrics for \(testParticipants) participants")
    }
    
    private func clearTestData() {
        // Clear all test-related UserDefaults
        let testKeys = [
            "group_workout_testing_mode",
            "testing_scenario",
            "test_group_workout",
            "pending_watch_command"
        ]
        
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear mock metrics
        for i in 1...10 {
            UserDefaults.standard.removeObject(forKey: "mock_metrics_\(i)")
        }
        
        addLog("✅ Test data cleared")
    }
    
    private func createTestGroupWorkout() -> GroupWorkout {
        GroupWorkout(
            id: UUID().uuidString,
            name: testWorkoutName,
            description: "Test workout for development",
            workoutType: .running,
            hostID: container.cloudKitManager.currentUserID ?? "test-host",
            maxParticipants: 10,
            scheduledStart: Date(),
            scheduledEnd: Date().addingTimeInterval(testDuration * 60),
            status: .scheduled,
            isPublic: true,
            tags: ["test", "debug"]
        )
    }
    
    private func sendWorkoutToWatch(_ workout: GroupWorkout) {
        guard WCSession.isSupported() && WCSession.default.isReachable else {
            addLog("❌ Watch not reachable")
            return
        }
        
        let message: [String: Any] = [
            "command": "startGroupWorkout",
            "workoutID": workout.id,
            "workoutName": workout.name,
            "workoutType": workout.workoutType.rawValue,
            "isHost": true
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { response in
            DispatchQueue.main.async {
                self.addLog("✅ Workout sent to Watch")
            }
        }, errorHandler: { error in
            DispatchQueue.main.async {
                self.addLog("❌ Failed to send: \(error.localizedDescription)")
            }
        })
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logMessages.append("[\(timestamp)] \(message)")
        
        // Keep only last 20 messages
        if logMessages.count > 20 {
            logMessages.removeFirst()
        }
    }
}

struct GroupWorkoutDebugView_Previews: PreviewProvider {
    static var previews: some View {
        GroupWorkoutDebugView()
    }
}
#endif