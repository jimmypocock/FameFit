//
//  GroupWorkoutSummaryView.swift
//  FameFit
//
//  Post-workout summary showing group results and individual performance
//

import SwiftUI
import HealthKit

struct GroupWorkoutSummaryView: View {
    let workout: GroupWorkout
    let personalWorkout: HKWorkout?
    let participants: [GroupWorkoutParticipant]
    let currentUserID: String
    
    @State private var participantProfiles: [String: UserProfile] = [:]
    @State private var isLoadingProfiles = true
    @State private var showShareSheet = false
    @State private var selectedTab: SummaryTab = .overview
    @Environment(\.dependencyContainer) private var container
    @Environment(\.dismiss) private var dismiss
    
    // Calculate rankings
    private var rankings: [ParticipantRanking] {
        participants
            .filter { $0.workoutData != nil }
            .map { participant in
                ParticipantRanking(
                    participant: participant,
                    profile: participantProfiles[participant.userID]
                )
            }
            .sorted { $0.participant.workoutData!.totalEnergyBurned > $1.participant.workoutData!.totalEnergyBurned }
    }
    
    private var userRank: Int? {
        rankings.firstIndex { $0.participant.userID == currentUserID }.map { $0 + 1 }
    }
    
    private var userParticipant: GroupWorkoutParticipant? {
        participants.first { $0.userID == currentUserID }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with workout info
                    headerSection
                    
                    // Tab selector
                    tabSelector
                    
                    // Tab content
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .personal:
                        personalContent
                    case .leaderboard:
                        leaderboardContent
                    }
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Workout Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [generateShareText()])
            }
            .task {
                await loadParticipantProfiles()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Workout title and type
            VStack(spacing: 8) {
                Text(workout.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    Label(workout.workoutType.displayName, systemImage: workout.workoutType.iconName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(formatWorkoutDuration())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Your placement
            if let rank = userRank {
                placementBadge(rank: rank, total: rankings.count)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func placementBadge(rank: Int, total: Int) -> some View {
        HStack(spacing: 8) {
            if rank <= 3 {
                Image(systemName: rank == 1 ? "trophy.fill" : "medal.fill")
                    .font(.title2)
                    .foregroundColor(medalColor(for: rank))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(placementText(for: rank))
                    .font(.headline)
                
                Text("out of \(total) participants")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.15),
                    Color.accentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(10)
    }
    
    private func placementText(for rank: Int) -> String {
        switch rank {
        case 1: return "🥇 1st Place!"
        case 2: return "🥈 2nd Place!"
        case 3: return "🥉 3rd Place!"
        default: return "\(rank)th Place"
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SummaryTab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.title,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
        }
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Overview Content
    
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Group statistics
            GroupStatsCard(
                totalParticipants: participants.count,
                completedCount: participants.filter { $0.status == .completed }.count,
                totalCalories: participants.compactMap { $0.workoutData?.totalEnergyBurned }.reduce(0, +),
                totalDistance: participants.compactMap { $0.workoutData?.totalDistance }.reduce(0, +),
                averageDuration: calculateAverageDuration()
            )
            
            // Top performers
            if !rankings.isEmpty {
                TopPerformersCard(rankings: Array(rankings.prefix(3)))
            }
            
            // Fun facts
            FunFactsCard(participants: participants, profiles: participantProfiles)
        }
    }
    
    // MARK: - Personal Content
    
    private var personalContent: some View {
        VStack(spacing: 16) {
            if let participant = userParticipant,
               let data = participant.workoutData {
                // Personal stats
                PersonalStatsCard(
                    data: data,
                    workout: personalWorkout,
                    rank: userRank,
                    totalParticipants: rankings.count
                )
                
                // Comparison with average
                if rankings.count > 1 {
                    ComparisonCard(
                        personalData: data,
                        groupAverage: calculateGroupAverages()
                    )
                }
                
                // Achievements earned
                if let personalWorkout = personalWorkout {
                    AchievementsCard(workout: personalWorkout)
                }
            } else {
                Text("No personal data available")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    // MARK: - Leaderboard Content
    
    private var leaderboardContent: some View {
        VStack(spacing: 8) {
            ForEach(Array(rankings.enumerated()), id: \.element.participant.id) { index, ranking in
                FinalLeaderboardRow(
                    rank: index + 1,
                    participant: ranking.participant,
                    profile: ranking.profile,
                    isCurrentUser: ranking.participant.userID == currentUserID
                )
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showShareSheet = true }) {
                Label("Share Results", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            
            if workout.hostID == currentUserID {
                Button(action: scheduleNextWorkout) {
                    Label("Schedule Next Workout", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BorderedButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadParticipantProfiles() async {
        isLoadingProfiles = true
        
        for participant in participants {
            do {
                let profile = try await container.userProfileService.fetchProfileByUserID(participant.userID)
                await MainActor.run {
                    participantProfiles[participant.userID] = profile
                }
            } catch {
                FameFitLogger.warning("Failed to load profile for \(participant.userID)", category: FameFitLogger.ui)
            }
        }
        
        await MainActor.run {
            isLoadingProfiles = false
        }
    }
    
    private func formatWorkoutDuration() -> String {
        let duration = workout.scheduledEnd.timeIntervalSince(workout.scheduledStart)
        let hours = Int(duration) / 3_600
        let minutes = (Int(duration) % 3_600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    private func calculateAverageDuration() -> TimeInterval {
        let durations = participants.compactMap { $0.workoutData?.duration }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / Double(durations.count)
    }
    
    private func calculateGroupAverages() -> GroupAverages {
        let workouts = participants.compactMap { $0.workoutData }
        guard !workouts.isEmpty else {
            return GroupAverages(calories: 0, distance: 0, heartRate: 0, duration: 0)
        }
        
        let count = Double(workouts.count)
        return GroupAverages(
            calories: workouts.map { $0.totalEnergyBurned }.reduce(0, +) / count,
            distance: workouts.compactMap { $0.totalDistance }.reduce(0, +) / count,
            heartRate: workouts.compactMap { $0.averageHeartRate }.reduce(0, +) / Double(workouts.compactMap { $0.averageHeartRate }.count),
            duration: workouts.map { $0.duration }.reduce(0, +) / count
        )
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray)
        case 3: return .orange
        default: return .clear
        }
    }
    
    private func generateShareText() -> String {
        var text = "Just completed \"\(workout.name)\" group workout! 💪\n\n"
        
        if let rank = userRank {
            text += "Placed \(rank) out of \(rankings.count) participants\n"
        }
        
        if let data = userParticipant?.workoutData {
            text += "🔥 \(Int(data.totalEnergyBurned)) calories burned\n"
            if let distance = data.totalDistance, distance > 0 {
                text += "📍 \(String(format: "%.2f", distance / 1_000)) km\n"
            }
            text += "⏱ \(formatDuration(data.duration))\n"
        }
        
        text += "\n#FameFit #GroupWorkout #Fitness"
        
        return text
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3_600
        let minutes = (Int(duration) % 3_600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func scheduleNextWorkout() {
        // Navigate to create workout view with pre-filled data
        // This would be handled by the parent view
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
    }
}

struct GroupStatsCard: View {
    let totalParticipants: Int
    let completedCount: Int
    let totalCalories: Double
    let totalDistance: Double
    let averageDuration: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GROUP STATISTICS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatBox(title: "Participants", value: "\(totalParticipants)", icon: "person.2.fill")
                StatBox(title: "Completed", value: "\(completedCount)", icon: "checkmark.circle.fill")
                StatBox(title: "Total Calories", value: "\(Int(totalCalories))", icon: "flame.fill")
                StatBox(title: "Total Distance", value: String(format: "%.1f km", totalDistance / 1_000), icon: "location.fill")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TopPerformersCard: View {
    let rankings: [ParticipantRanking]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP PERFORMERS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ForEach(Array(rankings.enumerated()), id: \.element.participant.id) { index, ranking in
                HStack {
                    Image(systemName: index == 0 ? "trophy.fill" : "medal.fill")
                        .foregroundColor(medalColor(for: index + 1))
                    
                    Text(ranking.profile?.username ?? "Unknown")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(Int(ranking.participant.workoutData?.totalEnergyBurned ?? 0)) cal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray)
        case 3: return .orange
        default: return .clear
        }
    }
}

struct PersonalStatsCard: View {
    let data: GroupWorkoutData
    let workout: HKWorkout?
    let rank: Int?
    let totalParticipants: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YOUR PERFORMANCE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // Main stats
            HStack(spacing: 20) {
                VStack {
                    Text("\(Int(data.totalEnergyBurned))")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let distance = data.totalDistance {
                    VStack {
                        Text(String(format: "%.2f", distance / 1_000))
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Kilometers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let heartRate = data.averageHeartRate {
                    VStack {
                        Text("\(Int(heartRate))")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Avg HR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ComparisonCard: View {
    let personalData: GroupWorkoutData
    let groupAverage: GroupAverages
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPARED TO GROUP AVERAGE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            ComparisonRow(
                label: "Calories",
                personal: personalData.totalEnergyBurned,
                average: groupAverage.calories
            )
            
            if let distance = personalData.totalDistance {
                ComparisonRow(
                    label: "Distance",
                    personal: distance / 1_000,
                    average: groupAverage.distance / 1_000,
                    format: "%.2f km"
                )
            }
            
            if let heartRate = personalData.averageHeartRate {
                ComparisonRow(
                    label: "Heart Rate",
                    personal: heartRate,
                    average: groupAverage.heartRate,
                    format: "%.0f bpm"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ComparisonRow: View {
    let label: String
    let personal: Double
    let average: Double
    var format: String = "%.0f"
    
    private var difference: Double {
        personal - average
    }
    
    private var percentDifference: Double {
        guard average > 0 else { return 0 }
        return (difference / average) * 100
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(String(format: format, personal))
                .font(.subheadline)
                .fontWeight(.medium)
            
            if difference != 0 {
                Text(String(format: "%+.0f%%", percentDifference))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(difference > 0 ? .green : .red)
            }
        }
    }
}

struct FunFactsCard: View {
    let participants: [GroupWorkoutParticipant]
    let profiles: [String: UserProfile]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FUN FACTS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // Add fun facts based on data
            VStack(alignment: .leading, spacing: 8) {
                if let mvp = findMVP() {
                    FunFactRow(
                        icon: "star.fill",
                        text: "\(mvp) burned the most calories!",
                        color: .yellow
                    )
                }
                
                if let speedster = findSpeedster() {
                    FunFactRow(
                        icon: "hare.fill",
                        text: "\(speedster) covered the most distance",
                        color: .blue
                    )
                }
                
                if let heartChamp = findHeartRateChamp() {
                    FunFactRow(
                        icon: "heart.fill",
                        text: "\(heartChamp) had the highest average heart rate",
                        color: .red
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func findMVP() -> String? {
        participants
            .max { ($0.workoutData?.totalEnergyBurned ?? 0) < ($1.workoutData?.totalEnergyBurned ?? 0) }
            .flatMap { profiles[$0.userID]?.username }
    }
    
    private func findSpeedster() -> String? {
        participants
            .max { ($0.workoutData?.totalDistance ?? 0) < ($1.workoutData?.totalDistance ?? 0) }
            .flatMap { profiles[$0.userID]?.username }
    }
    
    private func findHeartRateChamp() -> String? {
        participants
            .max { ($0.workoutData?.averageHeartRate ?? 0) < ($1.workoutData?.averageHeartRate ?? 0) }
            .flatMap { profiles[$0.userID]?.username }
    }
}

struct FunFactRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct AchievementsCard: View {
    let workout: HKWorkout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACHIEVEMENTS EARNED")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // This would check actual achievements
            Text("Check your achievements in the profile section")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct FinalLeaderboardRow: View {
    let rank: Int
    let participant: GroupWorkoutParticipant
    let profile: UserProfile?
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            // Rank
            if rank <= 3 {
                Image(systemName: rank == 1 ? "trophy.fill" : "medal.fill")
                    .foregroundColor(medalColor(for: rank))
                    .frame(width: 30)
            } else {
                Text("\(rank)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.username ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(isCurrentUser ? .semibold : .regular)
                
                if let data = participant.workoutData {
                    Text("\(Int(data.totalEnergyBurned)) cal • \(formatDuration(data.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            statusBadge(for: participant.status)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isCurrentUser ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray)
        case 3: return .orange
        default: return .clear
        }
    }
    
    private func statusBadge(for status: ParticipantStatus) -> some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(for: status).opacity(0.2))
            .foregroundColor(statusColor(for: status))
            .cornerRadius(4)
    }
    
    private func statusColor(for status: ParticipantStatus) -> Color {
        switch status {
        case .completed: return .green
        case .dropped: return .orange
        default: return .gray
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types

enum SummaryTab: String, CaseIterable {
    case overview
    case personal
    case leaderboard
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .personal: return "Personal"
        case .leaderboard: return "Leaderboard"
        }
    }
}

struct ParticipantRanking {
    let participant: GroupWorkoutParticipant
    let profile: UserProfile?
}

struct GroupAverages {
    let calories: Double
    let distance: Double
    let heartRate: Double
    let duration: TimeInterval
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
