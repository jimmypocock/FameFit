//
//  GroupWorkoutListView.swift
//  FameFit
//
//  View for displaying and managing group workouts
//

import SwiftUI

struct GroupWorkoutListView: View {
    @EnvironmentObject private var container: DependencyContainer
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
                            GroupWorkoutCard(workout: workout)
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
                .environmentObject(container)
        }
        .sheet(item: $selectedWorkout) { workout in
            GroupWorkoutDetailView(workout: workout)
                .environmentObject(container)
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

struct GroupWorkoutCard: View {
    let workout: GroupWorkout
    @EnvironmentObject private var container: DependencyContainer
    @State private var participantCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        Label(workoutTypeName, systemImage: workoutTypeIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if workout.isPublic {
                            Label("Public", systemImage: "globe")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(dayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(timeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                if let location = workout.location {
                    Label(location, systemImage: "location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("\(participantCount)/\(workout.maxParticipants)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
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
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            loadParticipantCount()
        }
    }
    
    private var workoutTypeName: String {
        if let type = Int(workout.workoutType),
           let activityType = HKWorkoutActivityType(rawValue: UInt(type)) {
            return activityType.displayName
        }
        return "Workout"
    }
    
    private var workoutTypeIcon: String {
        if let type = Int(workout.workoutType),
           let activityType = HKWorkoutActivityType(rawValue: UInt(type)) {
            return activityType.iconName
        }
        return "figure.run"
    }
    
    private var dayText: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: workout.timeZone) ?? .current
        
        let calendar = Calendar.current
        if calendar.isDateInToday(workout.scheduledDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(workout.scheduledDate) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: workout.scheduledDate)
        }
    }
    
    private var timeText: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: workout.timeZone) ?? .current
        formatter.timeStyle = .short
        return formatter.string(from: workout.scheduledDate)
    }
    
    private func loadParticipantCount() {
        Task {
            do {
                let participants = try await container.groupWorkoutSchedulingService.getParticipants(workout.id)
                await MainActor.run {
                    participantCount = participants.filter { $0.status == .accepted }.count
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
    
    private var service: GroupWorkoutSchedulingServicing?
    
    func configure(with container: DependencyContainer) {
        self.service = container.groupWorkoutSchedulingService
    }
    
    func loadUpcomingWorkouts() async {
        guard let service = service else { return }
        
        isLoading = true
        do {
            workouts = try await service.fetchUpcomingWorkouts(limit: 50)
            error = nil
        } catch {
            self.error = error
            print("Failed to load upcoming workouts: \(error)")
        }
        isLoading = false
    }
    
    func loadMyWorkouts() async {
        guard let service = service else { return }
        
        isLoading = true
        do {
            workouts = try await service.fetchMyWorkouts()
            error = nil
        } catch {
            self.error = error
            print("Failed to load my workouts: \(error)")
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
            workouts = allWorkouts.filter { $0.isPast }
            error = nil
        } catch {
            self.error = error
            print("Failed to load past workouts: \(error)")
        }
        isLoading = false
    }
}