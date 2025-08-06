//
//  GroupWorkoutsView.swift
//  FameFit
//
//  Main view for browsing and managing group workout sessions
//

import HealthKit
import SwiftUI

struct GroupWorkoutsView: View {
    @Environment(\.dependencyContainer) private var container
    @Environment(\.navigationCoordinator) private var navigationCoordinator
    @StateObject private var viewModel = GroupWorkoutsViewModel()

    @State private var showingCreateWorkout = false
    @State private var selectedTab: WorkoutTab = .upcoming
    @State private var showingJoinCodeInput = false
    @State private var joinCode = ""

    enum WorkoutTab: String, CaseIterable {
        case upcoming = "Upcoming"
        case active = "Live"
        case myWorkouts = "My Workouts"

        var icon: String {
            switch self {
            case .upcoming: "calendar"
            case .active: "dot.radiowaves.left.and.right"
            case .myWorkouts: "person.fill"
            }
        }
        
        var emptyStateIcon: String {
            switch self {
            case .upcoming: "calendar.badge.plus"
            case .active: "dot.radiowaves.left.and.right"
            case .myWorkouts: "person.circle"
            }
        }
        
        var emptyStateTitle: String {
            switch self {
            case .upcoming: "No Upcoming Workouts"
            case .active: "No Live Workouts"
            case .myWorkouts: "No Workouts Created"
            }
        }
        
        var emptyStateMessage: String {
            switch self {
            case .upcoming: "Join existing workouts or create your own to get started with group fitness!"
            case .active: "No workouts are currently in progress. Check back later or start one yourself!"
            case .myWorkouts: "Create a group workout to invite friends and train together!"
            }
        }
        
        var showsCreateButton: Bool {
            switch self {
            case .upcoming, .myWorkouts: true
            case .active: false
            }
        }
        
        var showsJoinButton: Bool {
            switch self {
            case .upcoming: true
            case .active, .myWorkouts: false
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Workout Type", selection: $selectedTab) {
                ForEach(WorkoutTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            TabView(selection: $selectedTab) {
                ForEach(WorkoutTab.allCases, id: \.self) { tab in
                    workoutList(for: tab)
                        .tag(tab)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Group")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingJoinCodeInput = true }) {
                    Image(systemName: "qrcode")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingCreateWorkout = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.refreshWorkouts(for: selectedTab)
        }
        .onAppear {
            FameFitLogger.info("🏋️ GroupWorkoutsView appeared", category: FameFitLogger.ui)
            if let navigationCoordinator = navigationCoordinator {
                viewModel.setup(
                    groupWorkoutService: container.groupWorkoutService,
                    currentUserId: container.cloudKitManager.currentUserID,
                    navigationCoordinator: navigationCoordinator
                )
            } else {
                // Fallback without navigation coordinator (shouldn't happen in practice)
                viewModel.setup(
                    groupWorkoutService: container.groupWorkoutService,
                    currentUserId: container.cloudKitManager.currentUserID,
                    navigationCoordinator: nil
                )
            }
        }
        .sheet(isPresented: $showingCreateWorkout) {
            CreateGroupWorkoutView()
                .environment(\.dependencyContainer, container)
                .environment(\.navigationCoordinator, navigationCoordinator)
        }
        .alert("Join Workout", isPresented: $showingJoinCodeInput) {
            TextField("Enter join code", text: $joinCode)
            Button("Join") {
                Task {
                    await viewModel.joinWithCode(joinCode)
                    joinCode = ""
                }
            }
            Button("Cancel", role: .cancel) {
                joinCode = ""
            }
        } message: {
            Text("Enter the 6-character join code shared by the workout host")
        }
    }

    // MARK: - Workout Lists

    private func workoutList(for tab: WorkoutTab) -> some View {
        Group {
            if viewModel.isLoading, workouts(for: tab).isEmpty {
                loadingView
            } else if tab == .upcoming && viewModel.hostingWorkouts.isEmpty && viewModel.participatingWorkouts.isEmpty && viewModel.publicWorkouts.isEmpty {
                emptyStateView(for: tab)
            } else if tab != .upcoming && workouts(for: tab).isEmpty {
                emptyStateView(for: tab)
            } else {
                if tab == .upcoming {
                    // Special sectioned view for upcoming workouts
                    upcomingSectionedList
                } else {
                    // Regular list for other tabs
                    regularWorkoutList(for: tab)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadWorkouts(for: tab)
            }
        }
    }
    
    private var upcomingSectionedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Combine all workouts without section headers
                ForEach(viewModel.hostingWorkouts, id: \.id) { workout in
                    workoutCard(for: workout)
                }
                
                ForEach(viewModel.participatingWorkouts, id: \.id) { workout in
                    workoutCard(for: workout)
                }
                
                ForEach(viewModel.publicWorkouts, id: \.id) { workout in
                    workoutCard(for: workout)
                }
                
                // Load more button
                if viewModel.hasMore(for: .upcoming) {
                    Button("Load More") {
                        Task {
                            await viewModel.loadMoreWorkouts(for: .upcoming)
                        }
                    }
                    .padding()
                    .foregroundColor(.blue)
                }
            }
            .padding(.vertical)
        }
    }
    
    private func regularWorkoutList(for tab: WorkoutTab) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(workouts(for: tab), id: \.id) { workout in
                    workoutCard(for: workout)
                }

                // Load more button
                if viewModel.hasMore(for: tab) {
                    Button("Load More") {
                        Task {
                            await viewModel.loadMoreWorkouts(for: tab)
                        }
                    }
                    .padding()
                    .foregroundColor(.blue)
                }
            }
            .padding()
        }
    }
    
    private func workoutCard(for workout: GroupWorkout) -> some View {
        Button {
            navigationCoordinator?.navigateToGroupWorkout(workout)
        } label: {
            GroupWorkoutCard(groupWorkout: workout)
                .environment(\.dependencyContainer, container)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading workouts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State Views

    private func emptyStateView(for tab: WorkoutTab) -> some View {
        VStack(spacing: 20) {
            Image(systemName: tab.emptyStateIcon)
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text(tab.emptyStateTitle)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(tab.emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action buttons
            VStack(spacing: 12) {
                if tab.showsCreateButton {
                    Button("Create Workout") {
                        showingCreateWorkout = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if tab.showsJoinButton {
                    Button("Join with Code") {
                        showingJoinCodeInput = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helper Methods

    private func workouts(for tab: WorkoutTab) -> [GroupWorkout] {
        switch tab {
        case .upcoming:
            viewModel.upcomingWorkouts
        case .active:
            viewModel.activeWorkouts
        case .myWorkouts:
            viewModel.myWorkouts
        }
    }
}

// MARK: - View Model

@MainActor
class GroupWorkoutsViewModel: ObservableObject {
    @Published var upcomingWorkouts: [GroupWorkout] = []
    @Published var activeWorkouts: [GroupWorkout] = []
    @Published var myWorkouts: [GroupWorkout] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Grouped upcoming workouts for sections
    @Published var hostingWorkouts: [GroupWorkout] = []
    @Published var participatingWorkouts: [GroupWorkout] = []
    @Published var publicWorkouts: [GroupWorkout] = []

    private var groupWorkoutService: GroupWorkoutServiceProtocol?
    var currentUserId: String?
    private var navigationCoordinator: NavigationCoordinator?

    private var hasMoreUpcoming = true
    private var hasMoreActive = true
    private var hasMoreMyWorkouts = true

    func setup(groupWorkoutService: GroupWorkoutServiceProtocol, currentUserId: String?, navigationCoordinator: NavigationCoordinator?) {
        self.groupWorkoutService = groupWorkoutService
        self.currentUserId = currentUserId
        self.navigationCoordinator = navigationCoordinator
    }

    func loadWorkouts(for tab: GroupWorkoutsView.WorkoutTab) async {
        FameFitLogger.info("🏋️ GroupWorkoutsViewModel loading workouts for tab: \(tab.rawValue)", category: FameFitLogger.ui)
        
        guard let service = groupWorkoutService else { 
            FameFitLogger.warning("🏋️ No groupWorkoutService configured", category: FameFitLogger.ui)
            return 
        }

        // Don't reload if already loaded
        let workouts = getWorkouts(for: tab)
        guard workouts.isEmpty else { 
            FameFitLogger.debug("🏋️ Workouts already loaded for tab: \(tab.rawValue), count: \(workouts.count)", category: FameFitLogger.ui)
            return 
        }

        isLoading = true

        do {
            let newWorkouts: [GroupWorkout]

            switch tab {
            case .upcoming:
                FameFitLogger.debug("🏋️ Fetching upcoming workouts via service", category: FameFitLogger.ui)
                newWorkouts = try await service.fetchUpcomingWorkouts(limit: 20)
                FameFitLogger.info("🏋️ Received \(newWorkouts.count) upcoming workouts", category: FameFitLogger.ui)
                
                // Log each workout for debugging
                for (index, workout) in newWorkouts.enumerated() {
                    FameFitLogger.debug("🏋️ Upcoming[\(index)]: \(workout.name) - Status: \(workout.status.rawValue) - End: \(workout.scheduledEnd)", category: FameFitLogger.ui)
                }
                
                upcomingWorkouts = newWorkouts
                groupUpcomingWorkouts()
                hasMoreUpcoming = newWorkouts.count == 20

            case .active:
                newWorkouts = try await service.fetchActiveWorkouts()
                activeWorkouts = newWorkouts
                hasMoreActive = newWorkouts.count == 20
                
            case .myWorkouts:
                newWorkouts = try await service.fetchMyWorkouts()
                myWorkouts = newWorkouts
                hasMoreMyWorkouts = false // No pagination for my workouts yet
            }
        } catch {
            FameFitLogger.error("🏋️ Failed to load workouts for tab \(tab.rawValue)", error: error, category: FameFitLogger.ui)
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMoreWorkouts(for tab: GroupWorkoutsView.WorkoutTab) async {
        guard let service = groupWorkoutService, hasMore(for: tab) else { return }

        do {
            let newWorkouts: [GroupWorkout]

            switch tab {
            case .upcoming:
                newWorkouts = try await service.fetchUpcomingWorkouts(limit: 20)
                upcomingWorkouts.append(contentsOf: newWorkouts)
                hasMoreUpcoming = newWorkouts.count == 20

            case .active:
                newWorkouts = try await service.fetchActiveWorkouts()
                activeWorkouts.append(contentsOf: newWorkouts)
                hasMoreActive = newWorkouts.count == 20
                
            case .myWorkouts:
                // My workouts doesn't have pagination yet
                newWorkouts = []
                hasMoreMyWorkouts = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshWorkouts() async {
        guard groupWorkoutService != nil else { return }

        // Only refresh the currently selected tab
        // This is called by pull-to-refresh, so we know which tab is active
        // For now, default to upcoming since it's the most common
        await refreshWorkouts(for: .upcoming)
    }
    
    func refreshWorkouts(for tab: GroupWorkoutsView.WorkoutTab) async {
        guard groupWorkoutService != nil else { return }
        
        // Clear only the data for the tab being refreshed
        switch tab {
        case .upcoming:
            upcomingWorkouts = []
            hostingWorkouts = []
            participatingWorkouts = []
            publicWorkouts = []
        case .active:
            activeWorkouts = []
        case .myWorkouts:
            myWorkouts = []
        }
        
        // Reload only the requested tab
        await loadWorkouts(for: tab)
    }


    func joinWithCode(_ code: String) async {
        guard let service = groupWorkoutService else { return }

        do {
            let joinedWorkout = try await service.joinWithCode(code)

            // Navigate to the joined workout detail view
            navigationCoordinator?.navigateToGroupWorkout(joinedWorkout)
            
            // Refresh workouts to update the list
            await refreshWorkouts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func hasMore(for tab: GroupWorkoutsView.WorkoutTab) -> Bool {
        switch tab {
        case .upcoming: hasMoreUpcoming
        case .active: hasMoreActive
        case .myWorkouts: hasMoreMyWorkouts
        }
    }

    private func getWorkouts(for tab: GroupWorkoutsView.WorkoutTab) -> [GroupWorkout] {
        switch tab {
        case .upcoming: upcomingWorkouts
        case .active: activeWorkouts
        case .myWorkouts: myWorkouts
        }
    }
    
    // MARK: - Grouping Logic
    
    private func groupUpcomingWorkouts() {
        FameFitLogger.debug("🏋️ Grouping \(upcomingWorkouts.count) upcoming workouts", category: FameFitLogger.ui)
        
        guard let userId = currentUserId else {
            // If no user ID, all workouts are public to view
            FameFitLogger.debug("🏋️ No user ID - showing all as public", category: FameFitLogger.ui)
            hostingWorkouts = []
            participatingWorkouts = []
            publicWorkouts = upcomingWorkouts.sorted { $0.scheduledStart < $1.scheduledStart }
            return
        }
        
        // Group workouts by user's relationship
        let hosting = upcomingWorkouts.filter { $0.hostId == userId }
            .sorted { $0.scheduledStart < $1.scheduledStart }
        
        let participating = upcomingWorkouts.filter { 
            $0.hostId != userId && $0.participantIDs.contains(userId)
        }
            .sorted { $0.scheduledStart < $1.scheduledStart }
        
        let publicOnly = upcomingWorkouts.filter { 
            $0.isPublic && $0.hostId != userId && !$0.participantIDs.contains(userId)
        }
            .sorted { $0.scheduledStart < $1.scheduledStart }
        
        // Update published properties
        hostingWorkouts = hosting
        participatingWorkouts = participating
        publicWorkouts = publicOnly
        
        FameFitLogger.debug("🏋️ Grouped workouts - Hosting: \(hosting.count), Participating: \(participating.count), Public: \(publicOnly.count)", category: FameFitLogger.ui)
    }
}

// MARK: - Preview

#Preview {
    GroupWorkoutsView()
        .environment(\.dependencyContainer, DependencyContainer())
}
