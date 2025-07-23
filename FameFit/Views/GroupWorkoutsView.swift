//
//  GroupWorkoutsView.swift
//  FameFit
//
//  Main view for browsing and managing group workout sessions
//

import SwiftUI
import HealthKit

struct GroupWorkoutsView: View {
    @Environment(\.dependencyContainer) private var container
    @StateObject private var viewModel = GroupWorkoutsViewModel()
    
    @State private var showingCreateWorkout = false
    @State private var selectedTab: WorkoutTab = .upcoming
    @State private var searchText = ""
    @State private var showingJoinCodeInput = false
    @State private var joinCode = ""
    
    enum WorkoutTab: String, CaseIterable {
        case upcoming = "Upcoming"
        case myWorkouts = "My Workouts" 
        case active = "Live"
        
        var icon: String {
            switch self {
            case .upcoming: return "calendar"
            case .myWorkouts: return "person.circle"
            case .active: return "dot.radiowaves.left.and.right"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab bar
                tabBar
                
                // Content
                TabView(selection: $selectedTab) {
                    ForEach(WorkoutTab.allCases, id: \.self) { tab in
                        workoutList(for: tab)
                            .tag(tab)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Group Workouts")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search workouts...")
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
        }
        .onAppear {
            viewModel.setup(
                groupWorkoutService: container.groupWorkoutService,
                currentUserId: container.cloudKitManager.currentUserID
            )
        }
        .sheet(isPresented: $showingCreateWorkout) {
            CreateGroupWorkoutView()
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
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack {
            ForEach(WorkoutTab.allCases, id: \.self) { tab in
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            
                            Text(tab.rawValue)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .blue : .secondary)
                        
                        // Active indicator
                        Rectangle()
                            .frame(height: 2)
                            .foregroundColor(selectedTab == tab ? .blue : .clear)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - Workout Lists
    
    private func workoutList(for tab: WorkoutTab) -> some View {
        Group {
            if viewModel.isLoading && workouts(for: tab).isEmpty {
                loadingView
            } else if workouts(for: tab).isEmpty {
                emptyStateView(for: tab)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredWorkouts(for: tab), id: \.id) { workout in
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
            Image(systemName: emptyStateIcon(for: tab))
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(emptyStateTitle(for: tab))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(emptyStateMessage(for: tab))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            emptyStateAction(for: tab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func workouts(for tab: WorkoutTab) -> [GroupWorkout] {
        switch tab {
        case .upcoming:
            return viewModel.upcomingWorkouts
        case .myWorkouts:
            return viewModel.myWorkouts
        case .active:
            return viewModel.activeWorkouts
        }
    }
    
    private func filteredWorkouts(for tab: WorkoutTab) -> [GroupWorkout] {
        let workouts = workouts(for: tab)
        
        if searchText.isEmpty {
            return workouts
        } else {
            return workouts.filter { workout in
                workout.name.localizedCaseInsensitiveContains(searchText) ||
                workout.description.localizedCaseInsensitiveContains(searchText) ||
                workout.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    private func emptyStateIcon(for tab: WorkoutTab) -> String {
        switch tab {
        case .upcoming: return "calendar.badge.plus"
        case .myWorkouts: return "person.circle.fill"
        case .active: return "dot.radiowaves.left.and.right"
        }
    }
    
    private func emptyStateTitle(for tab: WorkoutTab) -> String {
        switch tab {
        case .upcoming: return "No Upcoming Workouts"
        case .myWorkouts: return "No Workouts Created"
        case .active: return "No Live Workouts"
        }
    }
    
    private func emptyStateMessage(for tab: WorkoutTab) -> String {
        switch tab {
        case .upcoming: return "Join existing workouts or create your own to get started with group fitness!"
        case .myWorkouts: return "Create your first group workout and invite others to join your fitness journey."
        case .active: return "No workouts are currently in progress. Check back later or start one yourself!"
        }
    }
    
    @ViewBuilder
    private func emptyStateAction(for tab: WorkoutTab) -> some View {
        switch tab {
        case .upcoming:
            VStack(spacing: 12) {
                Button("Create Workout") {
                    showingCreateWorkout = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Join with Code") {
                    showingJoinCodeInput = true
                }
                .buttonStyle(.bordered)
            }
            
        case .myWorkouts:
            Button("Create Your First Workout") {
                showingCreateWorkout = true
            }
            .buttonStyle(.borderedProminent)
            
        case .active:
            EmptyView()
        }
    }
}

// MARK: - View Model

@MainActor
class GroupWorkoutsViewModel: ObservableObject {
    @Published var upcomingWorkouts: [GroupWorkout] = []
    @Published var myWorkouts: [GroupWorkout] = []
    @Published var activeWorkouts: [GroupWorkout] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var groupWorkoutService: GroupWorkoutServicing?
    var currentUserId: String?
    
    private var hasMoreUpcoming = true
    private var hasMoreMy = true
    private var hasMoreActive = true
    
    func setup(groupWorkoutService: GroupWorkoutServicing, currentUserId: String?) {
        self.groupWorkoutService = groupWorkoutService
        self.currentUserId = currentUserId
    }
    
    func loadWorkouts(for tab: GroupWorkoutsView.WorkoutTab) async {
        guard let service = groupWorkoutService else { return }
        
        // Don't reload if already loaded
        let workouts = getWorkouts(for: tab)
        guard workouts.isEmpty else { return }
        
        isLoading = true
        
        do {
            let newWorkouts: [GroupWorkout]
            
            switch tab {
            case .upcoming:
                newWorkouts = try await service.fetchUpcomingWorkouts(limit: 20)
                upcomingWorkouts = newWorkouts
                hasMoreUpcoming = newWorkouts.count == 20
                
            case .myWorkouts:
                guard let userId = currentUserId else { return }
                newWorkouts = try await service.fetchMyWorkouts(userId: userId)
                myWorkouts = newWorkouts
                hasMoreMy = newWorkouts.count == 20
                
            case .active:
                newWorkouts = try await service.fetchActiveWorkouts()
                activeWorkouts = newWorkouts
                hasMoreActive = newWorkouts.count == 20
            }
        } catch {
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
                
            case .myWorkouts:
                guard let userId = currentUserId else { return }
                newWorkouts = try await service.fetchMyWorkouts(userId: userId)
                myWorkouts.append(contentsOf: newWorkouts)
                hasMoreMy = newWorkouts.count == 20
                
            case .active:
                newWorkouts = try await service.fetchActiveWorkouts()
                activeWorkouts.append(contentsOf: newWorkouts)
                hasMoreActive = newWorkouts.count == 20
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func refreshWorkouts() async {
        guard groupWorkoutService != nil else { return }
        
        // Clear existing data
        upcomingWorkouts = []
        myWorkouts = []
        activeWorkouts = []
        
        // Reload all tabs
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadWorkouts(for: .upcoming) }
            group.addTask { await self.loadWorkouts(for: .myWorkouts) }
            group.addTask { await self.loadWorkouts(for: .active) }
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
            myWorkouts.removeAll { $0.id == workoutId }
            activeWorkouts.removeAll { $0.id == workoutId }
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
        case .upcoming: return hasMoreUpcoming
        case .myWorkouts: return hasMoreMy
        case .active: return hasMoreActive
        }
    }
    
    private func getWorkouts(for tab: GroupWorkoutsView.WorkoutTab) -> [GroupWorkout] {
        switch tab {
        case .upcoming: return upcomingWorkouts
        case .myWorkouts: return myWorkouts
        case .active: return activeWorkouts
        }
    }
}

// MARK: - Preview

#Preview {
    GroupWorkoutsView()
}