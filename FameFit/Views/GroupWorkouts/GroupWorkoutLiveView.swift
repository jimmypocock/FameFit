//
//  GroupWorkoutLiveView.swift
//  FameFit
//
//  Live dashboard for active group workouts
//

import SwiftUI
import Combine

struct GroupWorkoutLiveView: View {
    let workout: GroupWorkout
    
    @Environment(\.dependencyContainer) private var container
    @Environment(\.dismiss) private var dismiss
    
    @State private var participantMetrics: [String: WorkoutMetrics] = [:]
    @State private var participantProfiles: [String: UserProfile] = [:]
    @State private var elapsedTime: TimeInterval = 0
    @State private var isUploading = false
    @State private var lastMetricsUpdate = Date()
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isLoadingMetrics = true
    @State private var connectionStatus: ConnectionStatus = .connected
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionStatus {
        case connected
        case reconnecting
        case disconnected
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .reconnecting: return .orange
            case .disconnected: return .red
            }
        }
        
        var message: String {
            switch self {
            case .connected: return "Live"
            case .reconnecting: return "Reconnecting..."
            case .disconnected: return "Offline"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            if isLoadingMetrics && participantMetrics.isEmpty {
                // Initial loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Connecting to live workout...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Waiting for participants to sync")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if participantMetrics.isEmpty && !isLoadingMetrics {
                // No data state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No live data available")
                        .font(.headline)
                    Text("Make sure participants have started\ntheir workouts on Apple Watch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        Task {
                            await fetchLatestMetrics()
                        }
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with elapsed time
                        headerSection
                        
                        // Your metrics (if participating)
                        if let myMetrics = myCurrentMetrics {
                            yourMetricsCard(myMetrics)
                        }
                        
                        // Group totals
                        groupTotalsCard
                        
                        // Leaderboards
                        leaderboardSection
                        
                        // All participants
                        participantsSection
                    }
                    .padding()
                }
                .navigationTitle("Live Workout")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        .alert("Connection Error", isPresented: $showError) {
            Button("Retry") {
                Task {
                    await fetchLatestMetrics()
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unable to sync workout data. Please check your connection and try again.")
        }
        .onAppear {
            setupMetricsListener()
            loadParticipantProfiles()
            startMetricsPolling()
        }
        .onDisappear {
            cancellables.forEach { $0.cancel() }
        }
        .onReceive(timer) { _ in
            updateElapsedTime()
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(workout.name)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                Label(formatElapsedTime(elapsedTime), systemImage: "timer")
                    .font(.headline)
                
                Label("\(participantMetrics.count) Active", systemImage: "person.3.fill")
                    .font(.headline)
            }
            .foregroundColor(.secondary)
            
            // Connection status
            HStack(spacing: 4) {
                Circle()
                    .fill(connectionStatus.color)
                    .frame(width: 8, height: 8)
                Text(connectionStatus.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func yourMetricsCard(_ metrics: WorkoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Performance", systemImage: "person.fill")
                .font(.headline)
                .foregroundColor(.accentColor)
            
            HStack(spacing: 20) {
                metricItem(
                    value: "\(Int(metrics.heartRate ?? 0))",
                    unit: "BPM",
                    icon: "heart.fill",
                    color: .red
                )
                
                metricItem(
                    value: "\(Int(metrics.activeEnergyBurned ?? 0))",
                    unit: "CAL",
                    icon: "flame.fill",
                    color: .orange
                )
                
                if let distance = metrics.distance {
                    metricItem(
                        value: String(format: "%.2f", distance / 1000),
                        unit: "KM",
                        icon: "figure.run",
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.accentColor.opacity(0.1), Color.accentColor.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private var groupTotalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Group Totals", systemImage: "person.3.fill")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    Text("\(Int(totalCalories))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total CAL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text(String(format: "%.1f", totalDistance))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total KM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack {
                    Text("\(Int(averageHeartRate))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Avg BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leaderboard")
                .font(.headline)
            
            // Distance leaders
            if let distanceLeaders = topThreeByDistance {
                leaderboardRow(
                    title: "Distance",
                    leaders: distanceLeaders,
                    valueFormatter: { String(format: "%.2f km", ($0.distance ?? 0) / 1000) }
                )
            }
            
            // Calorie leaders
            if !topThreeByCalories.isEmpty {
                leaderboardRow(
                    title: "Calories",
                    leaders: topThreeByCalories,
                    valueFormatter: { "\(Int($0.activeEnergyBurned ?? 0)) cal" }
                )
            }
        }
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Participants")
                .font(.headline)
            
            ForEach(sortedParticipants, id: \.userID) { metrics in
                participantRow(metrics)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func metricItem(value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func leaderboardRow(
        title: String,
        leaders: [WorkoutMetrics],
        valueFormatter: @escaping (WorkoutMetrics) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(Array(leaders.enumerated()), id: \.element.userID) { index, metrics in
                HStack {
                    // Medal emoji for top 3
                    Text(index == 0 ? "🥇" : index == 1 ? "🥈" : "🥉")
                        .font(.title3)
                    
                    if let profile = participantProfiles[metrics.userID] {
                        Text(profile.username)
                            .fontWeight(.medium)
                    } else {
                        Text("User")
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Text(valueFormatter(metrics))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    private func participantRow(_ metrics: WorkoutMetrics) -> some View {
        HStack {
            // Profile image or placeholder
            if let profile = participantProfiles[metrics.userID],
               let urlString = profile.profileImageURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
            }
            
            // Name and metrics
            VStack(alignment: .leading, spacing: 4) {
                if let profile = participantProfiles[metrics.userID] {
                    Text(profile.username)
                        .fontWeight(.medium)
                } else {
                    Text("Participant")
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 12) {
                    if let hr = metrics.heartRate {
                        Label("\(Int(hr))", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if let energy = metrics.activeEnergyBurned {
                        Label("\(Int(energy))", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if let distance = metrics.distance {
                        Label(String(format: "%.1f", distance / 1000), systemImage: "figure.run")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Active indicator
            if metrics.isActive {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var myCurrentMetrics: WorkoutMetrics? {
        guard let userID = container.cloudKitManager.currentUserID else { return nil }
        return participantMetrics[userID]
    }
    
    private var sortedParticipants: [WorkoutMetrics] {
        participantMetrics.values.sorted { 
            ($0.activeEnergyBurned ?? 0) > ($1.activeEnergyBurned ?? 0) 
        }
    }
    
    private var topThreeByDistance: [WorkoutMetrics]? {
        let withDistance = participantMetrics.values.filter { $0.distance != nil }
        guard !withDistance.isEmpty else { return nil }
        return Array(withDistance.sorted { ($0.distance ?? 0) > ($1.distance ?? 0) }.prefix(3))
    }
    
    private var topThreeByCalories: [WorkoutMetrics] {
        let withCalories = participantMetrics.values.filter { $0.activeEnergyBurned != nil }
        return Array(withCalories.sorted { 
            ($0.activeEnergyBurned ?? 0) > ($1.activeEnergyBurned ?? 0) 
        }.prefix(3))
    }
    
    private var totalCalories: Double {
        participantMetrics.values.reduce(0) { $0 + ($1.activeEnergyBurned ?? 0) }
    }
    
    private var totalDistance: Double {
        participantMetrics.values.reduce(0) { $0 + ($1.distance ?? 0) } / 1000
    }
    
    private var averageHeartRate: Double {
        let heartRates = participantMetrics.values.compactMap { $0.heartRate }
        guard !heartRates.isEmpty else { return 0 }
        return heartRates.reduce(0, +) / Double(heartRates.count)
    }
    
    // MARK: - Helper Methods
    
    private func formatElapsedTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func updateElapsedTime() {
        elapsedTime = Date().timeIntervalSince(workout.scheduledStart)
    }
    
    // MARK: - Data Loading
    
    private func setupMetricsListener() {
        // Listen for metrics from Watch
        NotificationCenter.default.publisher(for: Notification.Name("WorkoutMetricsReceived"))
            .sink { notification in
                if let metrics = notification.userInfo as? [String: Any] {
                    self.handleIncomingMetrics(metrics)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleIncomingMetrics(_ metricsData: [String: Any]) {
        Task {
            guard let workoutID = metricsData["workoutID"] as? String,
                  workoutID == workout.id else { return }
            
            // Upload to CloudKit
            await uploadMetricsToCloudKit(metricsData)
        }
    }
    
    private func uploadMetricsToCloudKit(_ metricsData: [String: Any]) async {
        guard let userID = container.cloudKitManager.currentUserID else { return }
        
        isUploading = true
        defer { isUploading = false }
        
        // Create metrics object
        let metrics = WorkoutMetrics(
            workoutID: workout.id,
            userID: userID,
            creationDate: Date(),
            workoutType: workout.workoutType.displayName,
            groupWorkoutID: workout.id,
            sharingLevel: .groupOnly,
            heartRate: metricsData["heartRate"] as? Double,
            activeEnergyBurned: metricsData["activeEnergy"] as? Double,
            distance: metricsData["distance"] as? Double,
            elapsedTime: metricsData["elapsedTime"] as? TimeInterval ?? 0
        )
        
        // Upload to CloudKit
        do {
            let record = metrics.toCKRecord()
            _ = try await container.cloudKitManager.save(record)
            
            // Update local state
            await MainActor.run {
                self.participantMetrics[userID] = metrics
                self.lastMetricsUpdate = Date()
            }
        } catch {
            FameFitLogger.error("Failed to upload metrics", error: error, category: FameFitLogger.ui)
        }
    }
    
    private func loadParticipantProfiles() {
        Task {
            for participantID in participantMetrics.keys {
                if participantProfiles[participantID] == nil {
                    if let profile = try? await container.userProfileService.fetchProfileByUserID(participantID) {
                        await MainActor.run {
                            participantProfiles[participantID] = profile
                        }
                    }
                }
            }
        }
    }
    
    private func startMetricsPolling() {
        // Poll CloudKit for latest metrics every 5 seconds
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task {
                    await self.fetchLatestMetrics()
                }
            }
            .store(in: &cancellables)
    }
    
    private func fetchLatestMetrics() async {
        let predicate = NSPredicate(format: "groupWorkoutID == %@", workout.id)
        
        do {
            // Update connection status
            await MainActor.run {
                if connectionStatus == .disconnected {
                    connectionStatus = .reconnecting
                }
            }
            
            let records = try await container.cloudKitManager.fetchRecords(
                ofType: "WorkoutMetrics",
                predicate: predicate,
                sortDescriptors: [NSSortDescriptor(key: "creationDate", ascending: false)],
                limit: 50
            )
            
            // Process metrics
            var newMetrics: [String: WorkoutMetrics] = [:]
            for record in records {
                if let metrics = WorkoutMetrics(from: record) {
                    // Keep only the most recent metrics for each participant
                    if let existing = newMetrics[metrics.userID] {
                        if metrics.creationDate > existing.creationDate {
                            newMetrics[metrics.userID] = metrics
                        }
                    } else {
                        newMetrics[metrics.userID] = metrics
                    }
                }
            }
            
            await MainActor.run {
                self.participantMetrics = newMetrics
                self.isLoadingMetrics = false
                self.connectionStatus = .connected
                self.lastMetricsUpdate = Date()
                self.loadParticipantProfiles()
            }
        } catch {
            FameFitLogger.error("Failed to fetch metrics", error: error, category: FameFitLogger.ui)
            
            await MainActor.run {
                self.isLoadingMetrics = false
                self.connectionStatus = .disconnected
                
                // Show error if no data yet
                if self.participantMetrics.isEmpty {
                    self.errorMessage = "Unable to load workout data: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
}

// MARK: - Preview

struct GroupWorkoutLiveView_Previews: PreviewProvider {
    static var previews: some View {
        GroupWorkoutLiveView(
            workout: GroupWorkout(
                name: "Morning Run",
                description: "5K run in the park",
                workoutType: .running,
                hostID: "test-host",
                scheduledStart: Date(),
                scheduledEnd: Date().addingTimeInterval(1800)
            )
        )
    }
}