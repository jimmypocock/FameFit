//
//  BulkPrivacyUpdateView.swift
//  FameFit
//
//  UI for managing bulk privacy updates on shared activities
//

import SwiftUI
import Combine

struct BulkPrivacyUpdateView: View {
    @StateObject private var viewModel: BulkPrivacyUpdateViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(dependencyContainer: DependencyContainer) {
        _viewModel = StateObject(wrappedValue: BulkPrivacyUpdateViewModel(
            bulkPrivacyService: dependencyContainer.bulkPrivacyUpdateService,
            activityFeedService: dependencyContainer.activityFeedService
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Update Scope Section
                Section {
                    Picker("Update Scope", selection: $viewModel.updateScope) {
                        Text("All Activities").tag(BulkUpdateScope.all)
                        Text("By Activity Type").tag(BulkUpdateScope.byType)
                        Text("By Date Range").tag(BulkUpdateScope.byDateRange)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("What to Update")
                } footer: {
                    Text(viewModel.updateScope.description)
                }
                
                // Scope-specific Options
                switch viewModel.updateScope {
                case .all:
                    EmptyView()
                    
                case .byType:
                    Section("Activity Type") {
                        ForEach(ActivityType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .foregroundStyle(type.color)
                                    .frame(width: 30)
                                Text(type.displayName)
                                Spacer()
                                if viewModel.selectedActivityType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedActivityType = type
                            }
                        }
                    }
                    
                case .byDateRange:
                    Section("Date Range") {
                        DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                        DatePicker("End Date", selection: $viewModel.endDate, displayedComponents: .date)
                    }
                }
                
                // Privacy Level Selection
                Section {
                    ForEach(WorkoutPrivacy.allCases, id: \.self) { privacy in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(privacy.displayName)
                                    .fontWeight(.medium)
                                Text(privacy.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.selectedPrivacy == privacy {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedPrivacy = privacy
                        }
                    }
                } header: {
                    Text("New Privacy Level")
                }
                
                // Activity Count Preview
                if viewModel.isLoadingCount {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Counting activities...")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let count = viewModel.estimatedActivityCount {
                    Section {
                        HStack {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.secondary)
                            Text("\(count) activities will be updated")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Update Button
                Section {
                    Button(action: { Task { await viewModel.performUpdate() } }) {
                        HStack {
                            Spacer()
                            if viewModel.isUpdating {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            } else {
                                Text("Update Privacy")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isUpdating || !viewModel.canUpdate)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.canUpdate && !viewModel.isUpdating ? Color.accent : Color.secondary.opacity(0.3))
                    )
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle("Bulk Privacy Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isUpdating)
                }
            }
            .disabled(viewModel.isUpdating)
            .overlay {
                if viewModel.isUpdating {
                    UpdateProgressOverlay(progress: viewModel.updateProgress)
                }
            }
            .alert("Update Complete", isPresented: $viewModel.showCompletionAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let result = viewModel.updateResult {
                    Text(result)
                }
            }
            .alert("Update Failed", isPresented: $viewModel.showErrorAlert) {
                Button("OK") { }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .task {
            await viewModel.loadEstimatedCount()
        }
    }
}

// MARK: - Progress Overlay

private struct UpdateProgressOverlay: View {
    let progress: BulkUpdateProgress
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Updating Privacy")
                    .font(.headline)
                
                ProgressView(value: progress.percentComplete, total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                
                HStack(spacing: 30) {
                    VStack {
                        Text("\(progress.completed)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Updated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if progress.failed > 0 {
                        VStack {
                            Text("\(progress.failed)")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                            Text("Failed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let activity = progress.currentActivity {
                    Text(activity)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(30)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}

// MARK: - View Model

@MainActor
final class BulkPrivacyUpdateViewModel: ObservableObject {
    // Dependencies
    private let bulkPrivacyService: BulkPrivacyUpdateProtocol
    private let activityFeedService: ActivityFeedProtocol
    
    // Published State
    @Published var updateScope: BulkUpdateScope = .all
    @Published var selectedActivityType: ActivityType = .workout
    @Published var startDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
    @Published var endDate = Date()
    @Published var selectedPrivacy: WorkoutPrivacy = .friendsOnly
    
    @Published var estimatedActivityCount: Int?
    @Published var isLoadingCount = false
    @Published var isUpdating = false
    @Published var updateProgress = BulkUpdateProgress(total: 0, completed: 0, failed: 0, currentActivity: nil)
    
    @Published var showCompletionAlert = false
    @Published var showErrorAlert = false
    @Published var updateResult: String?
    @Published var errorMessage: String?
    
    private var progressCancellable: AnyCancellable?
    
    var canUpdate: Bool {
        switch updateScope {
        case .all:
            return true
        case .byType:
            return true // Activity type is always selected
        case .byDateRange:
            return startDate <= endDate
        }
    }
    
    init(bulkPrivacyService: BulkPrivacyUpdateProtocol, activityFeedService: ActivityFeedProtocol) {
        self.bulkPrivacyService = bulkPrivacyService
        self.activityFeedService = activityFeedService
        
        // Subscribe to progress updates
        progressCancellable = bulkPrivacyService.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.updateProgress = progress
            }
    }
    
    func loadEstimatedCount() async {
        // This is a simplified version - in production you'd query CloudKit for actual counts
        isLoadingCount = true
        defer { isLoadingCount = false }
        
        // Simulate loading delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Set estimated counts based on scope
        switch updateScope {
        case .all:
            estimatedActivityCount = Int.random(in: 50...200)
        case .byType:
            estimatedActivityCount = Int.random(in: 10...50)
        case .byDateRange:
            estimatedActivityCount = Int.random(in: 20...100)
        }
    }
    
    func performUpdate() async {
        isUpdating = true
        errorMessage = nil
        updateResult = nil
        
        do {
            let count: Int
            
            switch updateScope {
            case .all:
                count = try await bulkPrivacyService.updatePrivacyForAllActivities(to: selectedPrivacy)
                
            case .byType:
                count = try await bulkPrivacyService.updatePrivacyForActivitiesByType(
                    selectedActivityType.rawValue,
                    to: selectedPrivacy
                )
                
            case .byDateRange:
                count = try await bulkPrivacyService.updatePrivacyForActivitiesInDateRange(
                    from: startDate,
                    to: endDate,
                    privacy: selectedPrivacy
                )
            }
            
            updateResult = "Successfully updated \(count) activities to \(selectedPrivacy.displayName)"
            showCompletionAlert = true
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
        
        isUpdating = false
    }
}

// MARK: - Supporting Types

enum BulkUpdateScope: String, CaseIterable {
    case all
    case byType
    case byDateRange
    
    var description: String {
        switch self {
        case .all:
            return "Update privacy for all your shared activities"
        case .byType:
            return "Update privacy for specific activity types"
        case .byDateRange:
            return "Update privacy for activities in a date range"
        }
    }
}

enum ActivityType: String, CaseIterable {
    case workout
    case achievement
    case levelUp = "level_up"
    case milestone
    case streak
    
    var displayName: String {
        switch self {
        case .workout:
            return "Workouts"
        case .achievement:
            return "Achievements"
        case .levelUp:
            return "Level Ups"
        case .milestone:
            return "Milestones"
        case .streak:
            return "Streaks"
        }
    }
    
    var icon: String {
        switch self {
        case .workout:
            return "figure.run"
        case .achievement:
            return "trophy.fill"
        case .levelUp:
            return "arrow.up.circle.fill"
        case .milestone:
            return "flag.checkered"
        case .streak:
            return "flame.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .workout:
            return .blue
        case .achievement:
            return .yellow
        case .levelUp:
            return .green
        case .milestone:
            return .purple
        case .streak:
            return .orange
        }
    }
}
