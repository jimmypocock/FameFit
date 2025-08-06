//
//  GroupWorkoutListView.swift
//  FameFit
//
//  View for displaying and managing group workouts
//

import SwiftUI
import HealthKit

struct GroupWorkoutListView: View {
    @Environment(\.dependencyContainer) private var container
    @StateObject private var viewModel = GroupWorkoutListViewModel()
    
    @State private var selectedFilter: WorkoutFilter = .upcoming
    @State private var showCreateWorkout = false
    @State private var showJoinWorkout = false
    @State private var selectedWorkout: GroupWorkout?
    
    enum WorkoutFilter: String, CaseIterable {
        case upcoming = "Upcoming"
        case myWorkouts = "My Workouts"
        case discover = "Discover"
        case past = "Past"
        
        var icon: String {
            switch self {
            case .upcoming: return "calendar"
            case .myWorkouts: return "person.fill"
            case .discover: return "magnifyingglass"
            case .past: return "clock.arrow.circlepath"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(WorkoutFilter.allCases, id: \.self) { filter in
                        filterTab(filter)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            
            // Content
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isLoading && viewModel.workouts.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                    } else if viewModel.workouts.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(viewModel.workouts) { workout in
                            GroupWorkoutListCard(workout: workout)
                                .onTapGesture {
                                    selectedWorkout = workout
                                }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .refreshable {
                await refreshWorkouts()
            }
        }
        .navigationTitle("Group Workouts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showCreateWorkout = true }) {
                        Label("Create Workout", systemImage: "plus.circle")
                    }
                    
                    Button(action: { showJoinWorkout = true }) {
                        Label("Join with Code", systemImage: "qrcode")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $showCreateWorkout) {
            CreateGroupWorkoutView()
                .environment(\.dependencyContainer, container)
                .onDisappear {
                    // Switch to My Workouts tab after creating
                    selectedFilter = .myWorkouts
                    Task {
                        await refreshWorkouts()
                    }
                }
        }
        .sheet(item: $selectedWorkout) { workout in
            GroupWorkoutDetailView(workout: workout)
                .environment(\.dependencyContainer, container)
        }
        .onAppear {
            viewModel.configure(with: container)
            Task {
                await refreshWorkouts()
            }
        }
    }
    
    // MARK: - Views
    
    private func filterTab(_ filter: WorkoutFilter) -> some View {
        Button(action: {
            selectedFilter = filter
            Task {
                await refreshWorkouts()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.system(size: 20))
                
                Text(filter.rawValue)
                    .font(.caption)
            }
            .foregroundColor(selectedFilter == filter ? .primary : .secondary)
            .frame(minWidth: 60)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedFilter == filter ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if selectedFilter == .upcoming || selectedFilter == .discover {
                Button(action: { showCreateWorkout = true }) {
                    Label("Create Workout", systemImage: "plus.circle")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 50)
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .upcoming: return "calendar.badge.exclamationmark"
        case .myWorkouts: return "figure.run"
        case .discover: return "binoculars"
        case .past: return "clock"
        }
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .upcoming: return "No Upcoming Workouts"
        case .myWorkouts: return "No Workouts Created"
        case .discover: return "No Public Workouts"
        case .past: return "No Past Workouts"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .upcoming: return "Join a group workout or create your own to get started"
        case .myWorkouts: return "Create a group workout to invite friends and train together"
        case .discover: return "No public workouts available right now. Check back later!"
        case .past: return "Your completed group workouts will appear here"
        }
    }
    
    // MARK: - Actions
    
    private func refreshWorkouts() async {
        FameFitLogger.info("🔄 GroupWorkoutListView refreshing workouts for filter: \(selectedFilter.rawValue)", category: FameFitLogger.ui)
        switch selectedFilter {
        case .upcoming:
            await viewModel.loadUpcomingWorkouts()
        case .myWorkouts:
            await viewModel.loadMyWorkouts()
        case .discover:
            await viewModel.loadPublicWorkouts()
        case .past:
            await viewModel.loadPastWorkouts()
        }
    }
}

// MARK: - Group Workout Card

struct GroupWorkoutListCard: View {
    let workout: GroupWorkout
    @Environment(\.dependencyContainer) private var container
    @State private var participantCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.headline)
                        .foregroundColor(textColor)
                    
                    HStack(spacing: 8) {
                        Label(workoutTypeName, systemImage: workoutTypeIcon)
                            .font(.caption)
                            .foregroundColor(secondaryTextColor)
                        
                        // Time display under workout type
                        Text(statusTimeText)
                            .font(.caption)
                            .foregroundColor(statusTimeColor)
                    }
                }
                
                Spacer()
                
                // Public/Private indicator with participants count
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: workout.isPublic ? "person.2" : "lock")
                            .font(.system(size: 11))
                        Text(workout.isPublic ? "Public" : "Private")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(workout.isPublic ? .blue : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill((workout.isPublic ? Color.blue : Color.orange).opacity(0.1))
                    )
                    
                    // Participants count
                    Text("\(participantCount)/\(workout.maxParticipants)")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
            }
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                if let location = workout.location {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(secondaryTextColor)
                }
                
                if !workout.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(workout.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .onAppear {
            loadParticipantCount()
        }
    }
    
    private var workoutTypeName: String {
        workout.workoutType.displayName
    }
    
    private var workoutTypeIcon: String {
        workout.workoutType.iconName
    }
    
    // Background color based on status
    private var backgroundColor: Color {
        switch workout.status {
        case .active:
            return Color.green.opacity(0.05)
        case .scheduled:
            return Color(.secondarySystemBackground)
        case .completed, .cancelled:
            return Color(.systemGray6)
        }
    }
    
    // Text color for cancelled/ended workouts
    private var textColor: Color {
        switch workout.status {
        case .completed, .cancelled:
            return .gray
        default:
            return .primary
        }
    }
    
    private var secondaryTextColor: Color {
        switch workout.status {
        case .completed, .cancelled:
            return Color.gray.opacity(0.7)
        default:
            return .secondary
        }
    }
    
    // Time display logic
    private var statusTimeText: String {
        switch workout.status {
        case .active:
            return "Live"
        case .completed:
            return "Ended"
        case .cancelled:
            return "Cancelled"
        case .scheduled:
            let now = Date()
            if workout.scheduledDate > now {
                // Calculate time until start
                let interval = workout.scheduledDate.timeIntervalSince(now)
                if interval < 60 {
                    return "Starting Soon"
                } else if interval < 3600 {
                    let minutes = Int(interval / 60)
                    return "Starts in \(minutes)m"
                } else if interval < 86400 {
                    let hours = Int(interval / 3600)
                    return "Starts in \(hours)h"
                } else {
                    let days = Int(interval / 86400)
                    return "Starts in \(days)d"
                }
            } else {
                return "Starting Soon"
            }
        }
    }
    
    private var statusTimeColor: Color {
        switch workout.status {
        case .active:
            return .green
        case .completed, .cancelled:
            return Color.gray.opacity(0.7)
        case .scheduled:
            let now = Date()
            if workout.scheduledDate.timeIntervalSince(now) < 60 {
                return .orange // Starting soon
            }
            return .blue
        }
    }
    
    private func loadParticipantCount() {
        Task {
            do {
                let participants = try await container.groupWorkoutService.getParticipants(workout.id)
                await MainActor.run {
                    participantCount = participants.filter { $0.status == .joined }.count
                }
            } catch {
                print("Failed to load participant count: \(error)")
            }
        }
    }
}

// MARK: - View Model

@MainActor
class GroupWorkoutListViewModel: ObservableObject {
    @Published var workouts: [GroupWorkout] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var service: GroupWorkoutServiceProtocol?
    
    func configure(with container: DependencyContainer) {
        self.service = container.groupWorkoutService
    }
    
    func loadUpcomingWorkouts() async {
        guard let service = service else { 
            FameFitLogger.warning("📋 GroupWorkoutListViewModel: No service configured", category: FameFitLogger.ui)
            return 
        }
        
        FameFitLogger.info("📋 GroupWorkoutListViewModel loading upcoming workouts", category: FameFitLogger.ui)
        isLoading = true
        do {
            workouts = try await service.fetchUpcomingWorkouts(limit: 50)
            FameFitLogger.info("📋 GroupWorkoutListViewModel loaded \(workouts.count) upcoming workouts", category: FameFitLogger.ui)
            error = nil
        } catch {
            self.error = error
            FameFitLogger.error("Failed to load upcoming workouts", error: error, category: FameFitLogger.ui)
        }
        isLoading = false
    }
    
    func loadMyWorkouts() async {
        guard let service = service else { 
            FameFitLogger.warning("📋 GroupWorkoutListViewModel: No service configured", category: FameFitLogger.ui)
            return 
        }
        
        FameFitLogger.info("📋 GroupWorkoutListViewModel loading my workouts", category: FameFitLogger.ui)
        isLoading = true
        do {
            workouts = try await service.fetchMyWorkouts()
            FameFitLogger.info("📋 GroupWorkoutListViewModel loaded \(workouts.count) my workouts", category: FameFitLogger.ui)
            error = nil
        } catch {
            self.error = error
            FameFitLogger.error("Failed to load my workouts", error: error, category: FameFitLogger.ui)
        }
        isLoading = false
    }
    
    func loadPublicWorkouts() async {
        guard let service = service else { return }
        
        isLoading = true
        do {
            workouts = try await service.fetchPublicWorkouts(tags: nil, limit: 50)
            error = nil
        } catch {
            self.error = error
            print("Failed to load public workouts: \(error)")
        }
        isLoading = false
    }
    
    func loadPastWorkouts() async {
        guard let service = service else { return }
        
        isLoading = true
        do {
            // For now, we'll fetch all my workouts and filter for past ones
            let allWorkouts = try await service.fetchMyWorkouts()
            workouts = allWorkouts.filter { $0.scheduledEnd < Date() }
            error = nil
        } catch {
            self.error = error
            print("Failed to load past workouts: \(error)")
        }
        isLoading = false
    }
}