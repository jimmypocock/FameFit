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
    @EnvironmentObject var accountService: AccountVerificationService
    @EnvironmentObject var navigationCoordinator: WatchNavigationCoordinator
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @State private var username: String = "User"
    @State private var totalXP: Int = 0
    @State private var activeGroupWorkout: WatchGroupWorkout? = nil
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
    
    // Alternative: Use centralized configuration
    // private let workoutTypes: [WorkoutTypeItem] = WorkoutTypes.all.map { config in
    //     WorkoutTypeItem(type: config.type)
    // }

    // MARK: - View Components
    
    @ViewBuilder
    private var groupWorkoutSection: some View {
        if let workout = activeGroupWorkout {
            Section {
                Button(action: { startGroupWorkout(workout) }) {
                    VStack(alignment: .leading, spacing: 8) {
                        groupWorkoutHeader(workout)
                        Text(workout.name)
                            .font(.headline)
                            .lineLimit(2)
                        groupWorkoutFooter(workout)
                        Text("Tap to join")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(Color.green.opacity(0.15))
        }
    }
    
    private func groupWorkoutHeader(_ workout: WatchGroupWorkout) -> some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundColor(.green)
            Text("Active Group Workout")
                .font(.caption)
                .foregroundColor(.green)
            Spacer()
            if isHost(workout) {
                hostBadge
            }
        }
    }
    
    private var hostBadge: some View {
        Text("HOST")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green)
            .cornerRadius(4)
    }
    
    private func groupWorkoutFooter(_ workout: WatchGroupWorkout) -> some View {
        HStack {
            Image(systemName: workoutIconName(workout.workoutType))
                .font(.caption)
            Text(workoutDisplayName(workout.workoutType))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var userHeaderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    userInfo
                    Spacer()
                    refreshButton
                }
                .padding(.vertical, 4)
            }
        }
        .listRowBackground(Color.clear)
    }
    
    private var userInfo: some View {
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
        }
    }
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await refreshGroupWorkouts()
            }
        }) {
            Image(systemName: isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                .font(.title3)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var workoutTypesSection: some View {
        Section {
            ForEach(workoutTypes) { workoutType in
                workoutTypeButton(workoutType)
            }
        }
    }
    
    private func workoutTypeButton(_ workoutType: WorkoutTypeItem) -> some View {
        Button {
            workoutManager.selectedWorkout = workoutType.type
            navigationCoordinator.startWorkout(workoutType.type)
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
    
    var body: some View {
        List {
            groupWorkoutSection
            userHeaderSection
            workoutTypesSection
        }
        #if os(watchOS)
        .listStyle(.carousel)
        #endif
        .navigationBarTitle("Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshGroupWorkouts()
        }
        .onAppear {
            workoutManager.requestAuthorization()
            loadUserData()
            // Also refresh group workouts on appear
            Task {
                await refreshGroupWorkouts()
            }
        }
        .onChange(of: watchConnectivity.shouldStartWorkout) { _, shouldStart in
                FameFitLogger.debug("⌚ onChange shouldStartWorkout: \(shouldStart)", category: FameFitLogger.sync)
                if shouldStart, let workoutTypeRawValue = watchConnectivity.receivedWorkoutType {
                    FameFitLogger.info("⌚ Received workout type raw value: \(workoutTypeRawValue)", category: FameFitLogger.sync)
                    // Convert raw value to HKWorkoutActivityType
                    if let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRawValue)) {
                        FameFitLogger.info("⌚ Starting workout: \(workoutType)", category: FameFitLogger.sync)
                        // Start the workout
                        workoutManager.selectedWorkout = workoutType
                        navigationCoordinator.startWorkout(workoutType)
                        
                        // Reset the flag
                        DispatchQueue.main.async {
                            watchConnectivity.shouldStartWorkout = false
                            watchConnectivity.receivedWorkoutType = nil
                        }
                    } else {
                        FameFitLogger.error("⌚ Failed to create HKWorkoutActivityType from raw value: \(workoutTypeRawValue)", category: FameFitLogger.sync)
                    }
                } else {
                    FameFitLogger.debug("⌚ shouldStart: \(shouldStart), receivedWorkoutType: \(String(describing: watchConnectivity.receivedWorkoutType))", category: FameFitLogger.sync)
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
            activeGroupWorkout = createGroupWorkout(id: workoutID, name: workoutName, type: workoutType, isHost: isHost)
            
            FameFitLogger.info("⌚ Found pending group workout in UserDefaults: \(workoutName)", category: FameFitLogger.sync)
            return
        }
        
        // Also check application context from iPhone - but don't log repeatedly
        let context = WCSession.default.receivedApplicationContext
        // Only log if context has actual data
        if !context.isEmpty {
            FameFitLogger.debug("⌚ Application context contents: \(context)", category: FameFitLogger.sync)
        }
        
        if let command = context["command"] as? String,
           command == "startGroupWorkout",
           let workoutID = context["workoutID"] as? String,
           let workoutName = context["workoutName"] as? String,
           let workoutTypeRaw = context["workoutType"] as? Int,
           let isHost = context["isHost"] as? Bool {
            
            let workoutType = HKWorkoutActivityType(rawValue: UInt(workoutTypeRaw)) ?? .running
            
            // Set active group workout
            activeGroupWorkout = createGroupWorkout(id: workoutID, name: workoutName, type: workoutType, isHost: isHost)
            
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(workoutID, forKey: "pendingGroupWorkoutID")
            UserDefaults.standard.set(workoutName, forKey: "pendingGroupWorkoutName")
            UserDefaults.standard.set(isHost, forKey: "pendingGroupWorkoutIsHost")
            UserDefaults.standard.set(workoutTypeRaw, forKey: "pendingGroupWorkoutType")
            UserDefaults.standard.synchronize()
            
            FameFitLogger.info("⌚ Found pending group workout in application context: \(workoutName)", category: FameFitLogger.sync)
        }
    }
    
    private func startGroupWorkout(_ workout: WatchGroupWorkout) {
        FameFitLogger.info("⌚ Starting group workout: \(workout.name)", category: FameFitLogger.sync)
        
        // Set group workout ID for the manager
        workoutManager.groupWorkoutID = workout.id
        workoutManager.isGroupWorkoutHost = isHost(workout)
        
        // Start the workout (convert string back to enum)
        if let workoutType = workoutTypeFromString(workout.workoutType) {
            workoutManager.selectedWorkout = workoutType
            navigationCoordinator.startWorkout(workoutType)
        }
        
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
        
        // Check if there's pending content that hasn't been delivered
        if WCSession.default.hasContentPending {
            FameFitLogger.warning("⌚ WCSession has content pending during refresh - checking for stuck transfers", category: FameFitLogger.sync)
            
            // Log what's pending
            FameFitLogger.debug("⌚ Pending transfers - UserInfo: \(WCSession.default.outstandingUserInfoTransfers.count), Files: \(WCSession.default.outstandingFileTransfers.count)", category: FameFitLogger.sync)
            
            // Check received application context
            if !WCSession.default.receivedApplicationContext.isEmpty {
                FameFitLogger.info("⌚ Found application context during refresh!", category: FameFitLogger.sync)
                
                // Process it if it's a group workout
                let context = WCSession.default.receivedApplicationContext
                if let command = context["command"] as? String,
                   command == "startGroupWorkout" {
                    FameFitLogger.info("⌚ Processing group workout from application context", category: FameFitLogger.sync)
                    watchConnectivity.handleGroupWorkoutCommand(context)
                }
            }
        }
        
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
                        self.activeGroupWorkout = self.createGroupWorkout(id: workoutID, name: workoutName, type: workoutType, isHost: isHost)
                        
                        // Save to UserDefaults for persistence
                        UserDefaults.standard.set(workoutID, forKey: "pendingGroupWorkoutID")
                        UserDefaults.standard.set(workoutName, forKey: "pendingGroupWorkoutName")
                        UserDefaults.standard.set(isHost, forKey: "pendingGroupWorkoutIsHost")
                        UserDefaults.standard.set(workoutTypeRaw, forKey: "pendingGroupWorkoutType")
                        UserDefaults.standard.synchronize()
                        
                        FameFitLogger.info("⌚ Received active group workout from iPhone: \(workoutName)", category: FameFitLogger.sync)
                    }
                }
            }, errorHandler: { error in
                FameFitLogger.error("⌚ Failed to get active workout from iPhone: \(error)", category: FameFitLogger.sync)
            })
        }
        
        // Brief delay for UI feedback
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        isRefreshing = false
        
        #if DEBUG
        // Development warning if Watch connectivity isn't working
        if WCSession.default.hasContentPending && WCSession.default.outstandingUserInfoTransfers.isEmpty {
            FameFitLogger.warning("⚠️ Watch has pending content but can't receive it. This is a known Xcode development issue. Use TestFlight for reliable Watch↔iPhone communication.", category: FameFitLogger.sync)
        }
        #endif
    }
    
    // Helper to create a WatchGroupWorkout from Watch data
    private func createGroupWorkout(id: String, name: String, type: HKWorkoutActivityType, isHost: Bool) -> WatchGroupWorkout {
        WatchGroupWorkout(
            id: id,
            name: name,
            hostID: isHost ? (username.isEmpty ? "current_user" : username) : "other_user",
            workoutType: workoutTypeToString(type),
            scheduledStart: Date(),
            scheduledEnd: Date().addingTimeInterval(3600),
            maxParticipants: 10,
            currentParticipants: 1,
            isActive: true
        )
    }
    
    // Helper to check if current user is host
    private func isHost(_ workout: WatchGroupWorkout) -> Bool {
        // If we have a username, compare with hostID
        // Otherwise, check if hostID matches a placeholder we use for current user
        workout.hostID == username || workout.hostID == "current_user"
    }
    
    // Helper to convert HKWorkoutActivityType to String
    private func workoutTypeToString(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "running"
        case .walking: return "walking"
        case .cycling: return "cycling"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        case .pilates: return "pilates"
        case .functionalStrengthTraining: return "functionalstrength"
        case .traditionalStrengthTraining: return "strength"
        case .highIntensityIntervalTraining: return "hiit"
        case .rowing: return "rowing"
        case .elliptical: return "elliptical"
        case .stairs: return "stairs"
        default: return "other"
        }
    }
    
    // Helper to convert String to HKWorkoutActivityType
    private func workoutTypeFromString(_ string: String) -> HKWorkoutActivityType? {
        switch string.lowercased() {
        case "running": return .running
        case "walking": return .walking
        case "cycling": return .cycling
        case "swimming": return .swimming
        case "yoga": return .yoga
        case "pilates": return .pilates
        case "functionalstrength", "functional strength": return .functionalStrengthTraining
        case "strength", "traditional strength": return .traditionalStrengthTraining
        case "hiit", "highintensity": return .highIntensityIntervalTraining
        case "rowing": return .rowing
        case "elliptical": return .elliptical
        case "stairs", "stairclimbing": return .stairs
        default: return .other
        }
    }
    
    // Helper to get icon name for workout type
    private func workoutIconName(_ workoutType: String) -> String {
        // Convert string to HKWorkoutActivityType and use centralized config
        if let type = workoutTypeFromString(workoutType) {
            return WorkoutTypes.icon(for: type)
        }
        return "figure.mixed.cardio" // Default fallback
    }
    
    // Helper to get display name for workout type
    private func workoutDisplayName(_ workoutType: String) -> String {
        // Convert string to HKWorkoutActivityType and use centralized config
        if let type = workoutTypeFromString(workoutType) {
            return WorkoutTypes.name(for: type)
        }
        return "Workout" // Default fallback
    }
}

struct WatchStartView_Previews: PreviewProvider {
    static var previews: some View {
        WatchStartView()
    }
}
#endif
