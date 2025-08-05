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
            await viewModel.refreshWorkouts()
        }
        .onAppear {
            FameFitLogger.info("🏋️ GroupWorkoutsView appeared", category: FameFitLogger.ui)
            viewModel.setup(
                groupWorkoutService: container.groupWorkoutService,
                groupWorkoutSchedulingService: container.groupWorkoutSchedulingService,
                currentUserId: container.cloudKitManager.currentUserID
            )
        }
        .sheet(isPresented: $showingCreateWorkout) {
            CreateGroupWorkoutView()
                .environmentObject(container)
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
            } else if workouts(for: tab).isEmpty {
                emptyStateView(for: tab)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(workouts(for: tab), id: \.id) { workout in
                            GroupWorkoutCard(
                                groupWorkout: workout,
                                currentUserId: viewModel.currentUserId,
                                onJoin: {
                                    Task {
                                        await viewModel.joinWorkout(workout.id)
                                    }
                                },
                                onLeave: {
                                    Task {
                                        await viewModel.leaveWorkout(workout.id)
                                    }
                                },
                                onStart: {
                                    Task {
                                        await viewModel.startWorkout(workout.id)
                                    }
                                },
                                onViewDetails: {
                                    // Navigate to workout details
                                }
                            )
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
        }
        .onAppear {
            Task {
                await viewModel.loadWorkouts(for: tab)
            }
        }
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

    private var groupWorkoutService: GroupWorkoutServicing?
    private var groupWorkoutSchedulingService: GroupWorkoutSchedulingServicing?
    var currentUserId: String?

    private var hasMoreUpcoming = true
    private var hasMoreActive = true
    private var hasMoreMyWorkouts = true

    func setup(groupWorkoutService: GroupWorkoutServicing, groupWorkoutSchedulingService: GroupWorkoutSchedulingServicing?, currentUserId: String?) {
        self.groupWorkoutService = groupWorkoutService
        self.groupWorkoutSchedulingService = groupWorkoutSchedulingService
        self.currentUserId = currentUserId
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
                FameFitLogger.debug("🏋️ Received \(newWorkouts.count) upcoming workouts", category: FameFitLogger.ui)
                upcomingWorkouts = newWorkouts
                hasMoreUpcoming = newWorkouts.count == 20

            case .active:
                newWorkouts = try await service.fetchActiveWorkouts()
                activeWorkouts = newWorkouts
                hasMoreActive = newWorkouts.count == 20
                
            case .myWorkouts:
                if let schedulingService = groupWorkoutSchedulingService {
                    newWorkouts = try await schedulingService.fetchMyWorkouts()
                    myWorkouts = newWorkouts
                    hasMoreMyWorkouts = false // No pagination for my workouts yet
                } else {
                    newWorkouts = []
                }
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

        // Clear existing data
        upcomingWorkouts = []
        activeWorkouts = []
        myWorkouts = []

        // Reload all tabs
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadWorkouts(for: .upcoming) }
            group.addTask { await self.loadWorkouts(for: .active) }
            group.addTask { await self.loadWorkouts(for: .myWorkouts) }
        }
    }

    func joinWorkout(_ workoutId: String) async {
        guard let service = groupWorkoutService else { return }

        do {
            _ = try await service.joinGroupWorkout(workoutId: workoutId)

            // Refresh relevant lists
            await refreshWorkouts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leaveWorkout(_ workoutId: String) async {
        guard let service = groupWorkoutService else { return }

        do {
            try await service.leaveGroupWorkout(workoutId: workoutId)

            // Remove from local lists
            upcomingWorkouts.removeAll { $0.id == workoutId }
            activeWorkouts.removeAll { $0.id == workoutId }
            myWorkouts.removeAll { $0.id == workoutId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startWorkout(_ workoutId: String) async {
        guard let service = groupWorkoutService else { return }

        do {
            _ = try await service.startGroupWorkout(workoutId: workoutId)

            // Move workout to active list
            if let workout = upcomingWorkouts.first(where: { $0.id == workoutId }) {
                var updatedWorkout = workout
                updatedWorkout.status = .active

                upcomingWorkouts.removeAll { $0.id == workoutId }
                activeWorkouts.insert(updatedWorkout, at: 0)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinWithCode(_ code: String) async {
        guard let service = groupWorkoutService else { return }

        do {
            _ = try await service.joinWithCode(code)

            // Refresh workouts to show the joined workout
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
}

// MARK: - Preview

#Preview {
    GroupWorkoutsView()
}
