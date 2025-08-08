//
//  WatchStartView.swift
//  FameFit Watch App
//
//  Created by Jimmy Pocock on 2025/07/02.
//

#if os(watchOS)
import HealthKit
import SwiftUI
import WatchConnectivity

struct WorkoutTypeItem: Identifiable {
    let id = UUID()
    let type: HKWorkoutActivityType

    var name: String {
        type.displayName
    }
}

struct WatchStartView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @State private var navigationPath = NavigationPath()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @State private var username: String = "User"
    @State private var totalXP: Int = 0
    @State private var activeGroupWorkout: (id: String, name: String, type: HKWorkoutActivityType, isHost: Bool)? = nil
    @State private var isRefreshing = false

    // Complete list of workout types available on Watch
    private let workoutTypes: [WorkoutTypeItem] = [
        // Most Popular
        WorkoutTypeItem(type: .running),
        WorkoutTypeItem(type: .walking),
        WorkoutTypeItem(type: .cycling),
        WorkoutTypeItem(type: .swimming),
        WorkoutTypeItem(type: .traditionalStrengthTraining),
        WorkoutTypeItem(type: .yoga),
        WorkoutTypeItem(type: .highIntensityIntervalTraining),
        
        // Cardio
        WorkoutTypeItem(type: .elliptical),
        WorkoutTypeItem(type: .rowing),
        WorkoutTypeItem(type: .stairClimbing),
        WorkoutTypeItem(type: .jumpRope),
        
        // Strength
        WorkoutTypeItem(type: .functionalStrengthTraining),
        WorkoutTypeItem(type: .coreTraining),
        
        // Cross Training
        WorkoutTypeItem(type: .crossTraining),
        WorkoutTypeItem(type: .mixedCardio),
        
        // Mind & Body
        WorkoutTypeItem(type: .pilates),
        WorkoutTypeItem(type: .taiChi),
        WorkoutTypeItem(type: .mindAndBody),
        WorkoutTypeItem(type: .flexibility),
        
        // Sports
        WorkoutTypeItem(type: .basketball),
        WorkoutTypeItem(type: .soccer),
        WorkoutTypeItem(type: .tennis),
        WorkoutTypeItem(type: .golf),
        WorkoutTypeItem(type: .baseball),
        WorkoutTypeItem(type: .volleyball),
        WorkoutTypeItem(type: .badminton),
        WorkoutTypeItem(type: .pickleball),
        
        // Martial Arts
        WorkoutTypeItem(type: .boxing),
        WorkoutTypeItem(type: .kickboxing),
        WorkoutTypeItem(type: .martialArts),
        
        // Dance
        WorkoutTypeItem(type: .cardioDance),
        WorkoutTypeItem(type: .socialDance),
        WorkoutTypeItem(type: .barre),
        
        // Winter Sports
        WorkoutTypeItem(type: .snowboarding),
        WorkoutTypeItem(type: .downhillSkiing),
        WorkoutTypeItem(type: .crossCountrySkiing),
        
        // Water Sports
        WorkoutTypeItem(type: .surfingSports),
        WorkoutTypeItem(type: .paddleSports),
        
        // Other
        WorkoutTypeItem(type: .hiking),
        WorkoutTypeItem(type: .climbing),
        WorkoutTypeItem(type: .cooldown),
        WorkoutTypeItem(type: .other)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            // MARK: - LIST IN WATCH

            List {
                // Active Group Workout Section (if available)
                if let workout = activeGroupWorkout {
                    Section {
                        Button {
                            startGroupWorkout(workout)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "person.3.fill")
                                        .foregroundColor(.green)
                                    Text("Active Group Workout")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Spacer()
                                    if workout.isHost {
                                        Text("HOST")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text(workout.name)
                                    .font(.headline)
                                    .lineLimit(2)
                                
                                HStack {
                                    Image(systemName: workout.type.iconName)
                                        .font(.caption)
                                    Text(workout.type.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Tap to join")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color.green.opacity(0.15))
                }
                
                // User header section
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(username)
                                    .font(.headline)
                                    .lineLimit(1)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                    Text("\(totalXP) XP")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color.clear)
                
                // Workout types
                Section {
                    ForEach(workoutTypes) { workoutType in
                        Button {
                            workoutManager.selectedWorkout = workoutType.type
                            navigationPath.append(workoutType.type)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: workoutType.type.iconName)
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 28)
                                
                                Text(workoutType.type.displayName)
                                    .font(.system(.body, design: .default))
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .accessibilityIdentifier(workoutType.name)
                        .accessibilityLabel(workoutType.name)
                    }
                }
            } //: LIST
            #if os(watchOS)
            .listStyle(.carousel)
            #endif
            .navigationBarTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: HKWorkoutActivityType.self) { _ in
                SessionPagingView()
            }
            .refreshable {
                await refreshGroupWorkouts()
            }
            .onAppear {
                workoutManager.requestAuthorization()
                loadUserData()
            }
            .onChange(of: workoutManager.showingSummaryView) { _, isShowing in
                if !isShowing, !navigationPath.isEmpty {
                    // Clear navigation when summary is dismissed
                    navigationPath.removeLast(navigationPath.count)
                }
            }
            .onChange(of: watchConnectivity.shouldStartWorkout) { _, shouldStart in
                print("⌚ onChange shouldStartWorkout: \(shouldStart)")
                if shouldStart, let workoutTypeRawValue = watchConnectivity.receivedWorkoutType {
                    print("⌚ Received workout type raw value: \(workoutTypeRawValue)")
                    // Convert raw value to HKWorkoutActivityType
                    if let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRawValue)) {
                        print("⌚ Starting workout: \(workoutType)")
                        // Start the workout
                        workoutManager.selectedWorkout = workoutType
                        navigationPath.append(workoutType)
                        
                        // Reset the flag
                        DispatchQueue.main.async {
                            watchConnectivity.shouldStartWorkout = false
                            watchConnectivity.receivedWorkoutType = nil
                        }
                    } else {
                        print("⌚ Failed to create HKWorkoutActivityType from raw value: \(workoutTypeRawValue)")
                    }
                } else {
                    print("⌚ shouldStart: \(shouldStart), receivedWorkoutType: \(String(describing: watchConnectivity.receivedWorkoutType))")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserData() {
        // Try to load from UserDefaults (synced from iPhone)
        if let savedUsername = UserDefaults.standard.string(forKey: "watch_username") {
            username = savedUsername
        }
        
        if let savedXP = UserDefaults.standard.object(forKey: "watch_totalXP") as? Int {
            totalXP = savedXP
        }
        
        // Also check if data was sent via WatchConnectivity
        if let userData = watchConnectivity.lastReceivedUserData {
            if let name = userData["username"] as? String {
                username = name
            }
            if let xp = userData["totalXP"] as? Int {
                totalXP = xp
            }
        }
        
        // Check for pending group workout
        checkForPendingGroupWorkout()
    }
    
    private func checkForPendingGroupWorkout() {
        // First check UserDefaults
        if let workoutID = UserDefaults.standard.string(forKey: "pendingGroupWorkoutID"),
           let workoutName = UserDefaults.standard.string(forKey: "pendingGroupWorkoutName") {
            let isHost = UserDefaults.standard.bool(forKey: "pendingGroupWorkoutIsHost")
            
            // Get workout type if available
            let workoutTypeRaw = UserDefaults.standard.integer(forKey: "pendingGroupWorkoutType")
            let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRaw)) ?? .running
            
            // Set active group workout
            activeGroupWorkout = (id: workoutID, name: workoutName, type: workoutType, isHost: isHost)
            
            print("⌚ Found pending group workout in UserDefaults: \(workoutName)")
            return
        }
        
        // Also check application context from iPhone
        if let context = WCSession.default.receivedApplicationContext as? [String: Any],
           let command = context["command"] as? String,
           command == "startGroupWorkout",
           let workoutID = context["workoutID"] as? String,
           let workoutName = context["workoutName"] as? String,
           let workoutTypeRaw = context["workoutType"] as? Int,
           let isHost = context["isHost"] as? Bool {
            
            let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRaw)) ?? .running
            
            // Set active group workout
            activeGroupWorkout = (id: workoutID, name: workoutName, type: workoutType, isHost: isHost)
            
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(workoutID, forKey: "pendingGroupWorkoutID")
            UserDefaults.standard.set(workoutName, forKey: "pendingGroupWorkoutName")
            UserDefaults.standard.set(isHost, forKey: "pendingGroupWorkoutIsHost")
            UserDefaults.standard.set(workoutTypeRaw, forKey: "pendingGroupWorkoutType")
            UserDefaults.standard.synchronize()
            
            print("⌚ Found pending group workout in application context: \(workoutName)")
        }
    }
    
    private func startGroupWorkout(_ workout: (id: String, name: String, type: HKWorkoutActivityType, isHost: Bool)) {
        print("⌚ Starting group workout: \(workout.name)")
        
        // Set group workout ID for the manager
        workoutManager.groupWorkoutID = workout.id
        workoutManager.isGroupWorkoutHost = workout.isHost
        
        // Start the workout
        workoutManager.selectedWorkout = workout.type
        navigationPath.append(workout.type)
        
        // Clear pending workout from UserDefaults
        UserDefaults.standard.removeObject(forKey: "pendingGroupWorkoutID")
        UserDefaults.standard.removeObject(forKey: "pendingGroupWorkoutName")
        UserDefaults.standard.removeObject(forKey: "pendingGroupWorkoutIsHost")
        UserDefaults.standard.removeObject(forKey: "pendingGroupWorkoutType")
        UserDefaults.standard.synchronize()
        
        // Clear active workout
        activeGroupWorkout = nil
    }
    
    private func refreshGroupWorkouts() async {
        isRefreshing = true
        
        // First check for pending group workout from UserDefaults
        checkForPendingGroupWorkout()
        
        // Also try to sync with iPhone for active workouts
        if WCSession.default.isReachable {
            // Request active group workouts from iPhone
            WCSession.default.sendMessage(["request": "activeGroupWorkout"], replyHandler: { response in
                if let workoutData = response["groupWorkout"] as? [String: Any],
                   let workoutID = workoutData["id"] as? String,
                   let workoutName = workoutData["name"] as? String,
                   let workoutTypeRaw = workoutData["type"] as? Int,
                   let isHost = workoutData["isHost"] as? Bool {
                    
                    let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRaw)) ?? .running
                    
                    DispatchQueue.main.async {
                        self.activeGroupWorkout = (id: workoutID, name: workoutName, type: workoutType, isHost: isHost)
                        
                        // Save to UserDefaults for persistence
                        UserDefaults.standard.set(workoutID, forKey: "pendingGroupWorkoutID")
                        UserDefaults.standard.set(workoutName, forKey: "pendingGroupWorkoutName")
                        UserDefaults.standard.set(isHost, forKey: "pendingGroupWorkoutIsHost")
                        UserDefaults.standard.set(workoutTypeRaw, forKey: "pendingGroupWorkoutType")
                        UserDefaults.standard.synchronize()
                        
                        print("⌚ Received active group workout from iPhone: \(workoutName)")
                    }
                }
            }, errorHandler: { error in
                print("⌚ Failed to get active workout from iPhone: \(error)")
            })
        }
        
        // Brief delay for UI feedback
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        isRefreshing = false
        
        print("⌚ Refreshed group workouts")
    }
}

struct WatchStartView_Previews: PreviewProvider {
    static var previews: some View {
        WatchStartView()
    }
}
#endif
