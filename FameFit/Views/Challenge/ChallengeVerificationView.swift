//
//  ChallengeVerificationView.swift
//  FameFit
//
//  View for displaying workout challenge link verification status
//  and allowing manual verification requests
//

import SwiftUI

struct ChallengeVerificationView: View {
    // MARK: - Properties
    
    let link: WorkoutChallengeLink
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    @State private var isRequestingManualVerification = false
    @State private var manualVerificationNote = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private var verificationStatus: WorkoutVerificationStatus {
        WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            statusHeader
            
            if verificationStatus.canRequestManualVerification {
                manualVerificationSection
            }
            
            if link.manualVerificationRequested {
                pendingReviewSection
            }
            
            contributionDetails
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .alert("Verification", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var statusHeader: some View {
        HStack {
            Image(systemName: verificationStatus.icon)
                .foregroundColor(Color(verificationStatus.color))
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(verificationStatus.displayName)
                    .font(.headline)
                
                if let timestamp = link.verificationTimestamp {
                    Text("Verified \(timestamp, formatter: relativeDateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if verificationStatus.countsTowardProgress {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
    
    private var manualVerificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Request Manual Verification")
                .font(.headline)
            
            Text("If your workout wasn't automatically verified, you can request manual review.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("Add a note (optional)", text: $manualVerificationNote)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button(action: requestManualVerification) {
                if isRequestingManualVerification {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text("Request Manual Verification")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequestingManualVerification)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var pendingReviewSection: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading) {
                Text("Manual Review Pending")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let note = link.manualVerificationNote, !note.isEmpty {
                    Text("Note: \(note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var contributionDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Contribution")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatContribution())
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Workout Date")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(link.workoutDate, formatter: dateFormatter)
                    .font(.caption)
            }
            
            if let failureReason = link.failureReason,
               let reason = VerificationFailureReason(rawValue: failureReason) {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text(reason.userMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Actions
    
    private func requestManualVerification() {
        Task {
            isRequestingManualVerification = true
            
            do {
                _ = try await dependencyContainer.workoutChallengeLinksService.requestManualVerification(
                    linkID: link.id,
                    note: manualVerificationNote.isEmpty ? nil : manualVerificationNote
                )
                
                alertMessage = "Manual verification requested successfully. We'll review your workout and update the status soon."
                showingAlert = true
                manualVerificationNote = ""
            } catch {
                alertMessage = "Failed to request manual verification: \(error.localizedDescription)"
                showingAlert = true
            }
            
            isRequestingManualVerification = false
        }
    }
    
    // MARK: - Helpers
    
    private func formatContribution() -> String {
        switch link.contributionType {
        case "distance":
            let km = link.contributionValue / 1000
            return String(format: "%.2f km", km)
        case "calories":
            return String(format: "%.0f cal", link.contributionValue)
        case "duration":
            let minutes = link.contributionValue / 60
            return String(format: "%.0f min", minutes)
        case "count":
            return "1 workout"
        default:
            return String(format: "%.1f", link.contributionValue)
        }
    }
    
    // MARK: - Formatters
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

// MARK: - Challenge Verification List View

struct ChallengeVerificationListView: View {
    // MARK: - Properties
    
    let workoutChallengeID: String
    @EnvironmentObject var dependencyContainer: DependencyContainer
    
    @State private var links: [WorkoutChallengeLink] = []
    @State private var isLoading = true
    @State private var selectedFilter: VerificationFilter = .all
    
    enum VerificationFilter: String, CaseIterable {
        case all = "All"
        case verified = "Verified"
        case pending = "Pending"
        case failed = "Failed"
        
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .verified: return "checkmark.circle.fill"
            case .pending: return "clock"
            case .failed: return "exclamationmark.triangle"
            }
        }
    }
    
    private var filteredLinks: [WorkoutChallengeLink] {
        switch selectedFilter {
        case .all:
            return links
        case .verified:
            return links.filter { link in
                let status = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
                return status.countsTowardProgress
            }
        case .pending:
            return links.filter { link in
                let status = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
                return status == .pending
            }
        case .failed:
            return links.filter { link in
                let status = WorkoutVerificationStatus(rawValue: link.verificationStatus) ?? .pending
                return status == .failed
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            filterPicker
            
            if isLoading {
                ProgressView("Loading contributions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredLinks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredLinks) { link in
                            ChallengeVerificationView(link: link)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Challenge Contributions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadLinks()
        }
        .refreshable {
            await loadLinks()
        }
    }
    
    // MARK: - Subviews
    
    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(VerificationFilter.allCases, id: \.self) { filter in
                Label(filter.rawValue, systemImage: filter.icon)
                    .tag(filter)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No \(selectedFilter == .all ? "" : selectedFilter.rawValue.lowercased()) contributions")
                .font(.headline)
            
            Text("Complete workouts to contribute to this challenge")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Data Loading
    
    private func loadLinks() async {
        isLoading = true
        
        do {
            guard let userID = dependencyContainer.cloudKitManager.currentUserID else { return }
            
            links = try await dependencyContainer.workoutChallengeLinksService.fetchUserLinks(
                userID: userID,
                workoutChallengeID: workoutChallengeID
            )
        } catch {
            FameFitLogger.error("Failed to load challenge links", error: error, category: FameFitLogger.ui)
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#if DEBUG
struct ChallengeVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample link for preview
        let sampleLink = WorkoutChallengeLink(
            id: "preview-link",
            workoutID: "workout-123",
            workoutChallengeID: "challenge-456",
            userID: "user-789",
            contributionValue: 5000,
            contributionType: "distance",
            workoutDate: Date().addingTimeInterval(-3600),
            verificationStatus: .pending
        )
        
        // Preview individual verification view
        // Note: This is a static preview - buttons won't work without proper DependencyContainer
        ScrollView {
            VStack(spacing: 20) {
                // Pending status
                ChallengeVerificationView(link: sampleLink)
                    .previewDisplayName("Pending")
                
                // Verified status
                ChallengeVerificationView(link: WorkoutChallengeLink(
                    id: "preview-link-2",
                    workoutID: "workout-123",
                    workoutChallengeID: "challenge-456",
                    userID: "user-789",
                    contributionValue: 5000,
                    contributionType: "distance",
                    workoutDate: Date().addingTimeInterval(-7200),
                    verificationStatus: .autoVerified,
                    verificationTimestamp: Date().addingTimeInterval(-3600)
                ))
                .previewDisplayName("Verified")
                
                // Failed status
                ChallengeVerificationView(link: WorkoutChallengeLink(
                    id: "preview-link-3",
                    workoutID: "workout-123",
                    workoutChallengeID: "challenge-456",
                    userID: "user-789",
                    contributionValue: 5000,
                    contributionType: "distance",
                    workoutDate: Date().addingTimeInterval(-10800),
                    verificationStatus: .failed,
                    failureReason: .healthKitDataMissing,
                    verificationAttempts: 3
                ))
                .previewDisplayName("Failed")
            }
            .padding()
        }
        // Note: Preview is static only - interactive features require running the app
        
        // Note: Full list view requires DependencyContainer
        // To test the full list, run the app with test data
    }
}
#endif