//
//  GroupWorkoutLeaderboardView.swift
//  FameFit
//
//  Live leaderboard during group workouts showing real-time participant metrics
//

import SwiftUI
import HealthKit

struct GroupWorkoutLeaderboardView: View {
    @ObservedObject var coordinator: GroupWorkoutCoordinator
    @State private var selectedMetric: LeaderboardMetric = .calories
    @State private var showFullLeaderboard = false
    @Environment(\.dependencyContainer) private var container
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with workout info
            headerSection
            
            // Metric selector
            metricSelector
            
            // Live leaderboard
            if coordinator.participantMetrics.isEmpty {
                emptyStateView
            } else {
                leaderboardContent
            }
            
            // Aggregate stats
            if let aggregate = coordinator.aggregateMetrics {
                aggregateStatsView(aggregate)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .sheet(isPresented: $showFullLeaderboard) {
            FullLeaderboardView(
                coordinator: coordinator,
                selectedMetric: $selectedMetric
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if let workoutName = coordinator.currentGroupWorkout?.name {
                    Text(workoutName)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    // Connection status
                    connectionStatusBadge
                    
                    // Participant count
                    if !coordinator.participantMetrics.isEmpty {
                        Label("\(coordinator.participantMetrics.count)", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Host badge
                    if coordinator.currentGroupWorkout?.hostID == container.cloudKitManager.currentUserID {
                        Text("HOST")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Sync status
            syncStatusIndicator
        }
    }
    
    private var connectionStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            
            Text(connectionText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectionColor: Color {
        switch coordinator.connectionState {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .disconnected, .failed: return .red
        }
    }
    
    private var connectionText: String {
        switch coordinator.connectionState {
        case .connected: return "Live"
        case .connecting: return "Connecting"
        case .reconnecting: return "Reconnecting"
        case .disconnected: return "Offline"
        case .failed: return "Failed"
        }
    }
    
    private var syncStatusIndicator: some View {
        Group {
            switch coordinator.syncStatus {
            case .syncing:
                ProgressView()
                    .scaleEffect(0.8)
            case .synced:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))
            case .idle:
                EmptyView()
            }
        }
    }
    
    // MARK: - Metric Selector
    
    private var metricSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LeaderboardMetric.allCases, id: \.self) { metric in
                    MetricChip(
                        metric: metric,
                        isSelected: selectedMetric == metric,
                        action: { selectedMetric = metric }
                    )
                }
            }
        }
    }
    
    // MARK: - Leaderboard Content
    
    private var leaderboardContent: some View {
        VStack(spacing: 8) {
            // Top 3 participants
            ForEach(Array(sortedParticipants.prefix(3).enumerated()), id: \.element.0) { index, participant in
                GroupLeaderboardRow(
                    rank: index + 1,
                    userID: participant.0,
                    data: participant.1,
                    metric: selectedMetric,
                    isCurrentUser: participant.0 == container.cloudKitManager.currentUserID,
                    showMedal: true
                )
                .environment(\.dependencyContainer, container)
            }
            
            // Show more button if there are more participants
            if sortedParticipants.count > 3 {
                Button(action: { showFullLeaderboard = true }) {
                    HStack {
                        Text("View All (\(sortedParticipants.count) participants)")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var sortedParticipants: [(String, GroupWorkoutData)] {
        coordinator.participantMetrics.sorted { lhs, rhs in
            switch selectedMetric {
            case .calories:
                return lhs.value.totalEnergyBurned > rhs.value.totalEnergyBurned
            case .distance:
                return (lhs.value.totalDistance ?? 0) > (rhs.value.totalDistance ?? 0)
            case .heartRate:
                return (lhs.value.currentHeartRate ?? 0) > (rhs.value.currentHeartRate ?? 0)
            case .duration:
                return lhs.value.duration > rhs.value.duration
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Waiting for participants...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if coordinator.connectionState != .connected {
                Text("Check your connection")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Aggregate Stats
    
    private func aggregateStatsView(_ stats: AggregateWorkoutMetrics) -> some View {
        VStack(spacing: 12) {
            Divider()
            
            Text("GROUP TOTALS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                StatItem(
                    value: "\(Int(stats.totalCaloriesBurned))",
                    label: "Total Cal",
                    icon: "flame.fill",
                    color: .orange
                )
                
                if stats.totalDistance > 0 {
                    StatItem(
                        value: String(format: "%.1f", stats.totalDistance / 1_000),
                        label: "Total km",
                        icon: "location.fill",
                        color: .blue
                    )
                }
                
                StatItem(
                    value: "\(Int(stats.averageHeartRate))",
                    label: "Avg HR",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Views

struct MetricChip: View {
    let metric: LeaderboardMetric
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: metric.icon)
                    .font(.caption)
                Text(metric.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

struct GroupLeaderboardRow: View {
    let rank: Int
    let userID: String
    let data: GroupWorkoutData
    let metric: LeaderboardMetric
    let isCurrentUser: Bool
    let showMedal: Bool
    
    @State private var userProfile: UserProfile?
    @Environment(\.dependencyContainer) private var container
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank or medal
            if showMedal && rank <= 3 {
                medalView(for: rank)
            } else {
                Text("\(rank)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }
            
            // User info
            HStack(spacing: 8) {
                // Avatar
                if let avatarURL = userProfile?.profileImageURL,
                   let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(userProfile?.username ?? "Loading...")
                            .font(.subheadline)
                            .fontWeight(isCurrentUser ? .semibold : .regular)
                        
                        if userProfile?.isVerified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                        }
                        
                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Status indicator
                    if data.isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Active")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Metric value
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMetricValue(metric, data: data))
                    .font(.headline)
                    .foregroundColor(isCurrentUser ? .accentColor : .primary)
                
                Text(metric.unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrentUser ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground))
        .cornerRadius(10)
        .task {
            await loadUserProfile()
        }
    }
    
    private func medalView(for rank: Int) -> some View {
        Image(systemName: rank == 1 ? "medal.fill" : "medal")
            .font(.system(size: 24))
            .foregroundColor(medalColor(for: rank))
            .frame(width: 30)
    }
    
    private func medalColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(.systemGray)
        case 3: return .orange
        default: return .clear
        }
    }
    
    private func formatMetricValue(_ metric: LeaderboardMetric, data: GroupWorkoutData) -> String {
        switch metric {
        case .calories:
            return "\(Int(data.totalEnergyBurned))"
        case .distance:
            let km = (data.totalDistance ?? 0) / 1_000
            return String(format: "%.2f", km)
        case .heartRate:
            return "\(Int(data.currentHeartRate ?? 0))"
        case .duration:
            return formatDuration(data.duration)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func loadUserProfile() async {
        do {
            userProfile = try await container.userProfileService.fetchProfileByUserID(userID)
        } catch {
            FameFitLogger.warning("Failed to load profile for user \(userID)", category: FameFitLogger.ui)
        }
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Full Leaderboard Sheet

struct FullLeaderboardView: View {
    @ObservedObject var coordinator: GroupWorkoutCoordinator
    @Binding var selectedMetric: LeaderboardMetric
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencyContainer) private var container
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 8) {
                    // Metric selector at top
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(LeaderboardMetric.allCases, id: \.self) { metric in
                                MetricChip(
                                    metric: metric,
                                    isSelected: selectedMetric == metric,
                                    action: { selectedMetric = metric }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    
                    // All participants
                    ForEach(Array(sortedParticipants.enumerated()), id: \.element.0) { index, participant in
                        GroupLeaderboardRow(
                            rank: index + 1,
                            userID: participant.0,
                            data: participant.1,
                            metric: selectedMetric,
                            isCurrentUser: participant.0 == container.cloudKitManager.currentUserID,
                            showMedal: index < 3
                        )
                        .environment(\.dependencyContainer, container)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var sortedParticipants: [(String, GroupWorkoutData)] {
        coordinator.participantMetrics.sorted { lhs, rhs in
            switch selectedMetric {
            case .calories:
                return lhs.value.totalEnergyBurned > rhs.value.totalEnergyBurned
            case .distance:
                return (lhs.value.totalDistance ?? 0) > (rhs.value.totalDistance ?? 0)
            case .heartRate:
                return (lhs.value.currentHeartRate ?? 0) > (rhs.value.currentHeartRate ?? 0)
            case .duration:
                return lhs.value.duration > rhs.value.duration
            }
        }
    }
}

// MARK: - Supporting Types

enum LeaderboardMetric: String, CaseIterable {
    case calories
    case distance
    case heartRate
    case duration
    
    var displayName: String {
        switch self {
        case .calories: return "Calories"
        case .distance: return "Distance"
        case .heartRate: return "Heart Rate"
        case .duration: return "Duration"
        }
    }
    
    var icon: String {
        switch self {
        case .calories: return "flame.fill"
        case .distance: return "location.fill"
        case .heartRate: return "heart.fill"
        case .duration: return "clock.fill"
        }
    }
    
    var unit: String {
        switch self {
        case .calories: return "cal"
        case .distance: return "km"
        case .heartRate: return "bpm"
        case .duration: return ""
        }
    }
}
