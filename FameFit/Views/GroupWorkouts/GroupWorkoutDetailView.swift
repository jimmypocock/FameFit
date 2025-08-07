//
//  GroupWorkoutDetailView.swift
//  FameFit
//
//  Detailed view for a group workout with participants and actions
//

import SwiftUI
import HealthKit

struct GroupWorkoutDetailView: View {
    @State var workout: GroupWorkout
    var onDelete: (() -> Void)? = nil  // Callback for when workout is deleted
    @Environment(\.dependencyContainer) private var container
    @Environment(\.dismiss) private var dismiss
    
    @State private var participants: [GroupWorkoutParticipant] = []
    @State private var participantProfiles: [String: UserProfile] = [:]
    @State private var hostProfile: UserProfile?
    @State private var myParticipation: GroupWorkoutParticipant?
    @State private var isLoading = true
    @State private var showHostProfile = false
    @State private var showInviteSheet = false
    @State private var showDeleteAlert = false
    @State private var isCalendarAdded = false
    @State private var showCalendarDeniedAlert = false
    @State private var showCalendarSuccessAlert = false
    @State private var calendarSuccessMessage = ""
    
    @State private var currentUserID: String?
    
    private var isCreator: Bool {
        guard let currentUserID = currentUserID else { return false }
        let result = workout.hostId == currentUserID
        print("isCreator check: hostId=\(workout.hostId), currentUserID=\(currentUserID), isCreator=\(result)")
        return result
    }
    
    private var acceptedCount: Int {
        participants.filter { $0.status == .joined }.count
    }
    
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Workout type and status info
                    workoutInfoSection
                    
                    // Quick Actions
                    if workout.status == .scheduled || workout.status == .active {
                        quickActionsSection
                    }
                    
                    // Details - only show if there's content
                    if workout.location != nil || workout.notes != nil || !workout.tags.isEmpty {
                        detailsSection
                    }
                    
                    // Participants
                    participantsSection
                    
                    // Management actions
                    if (isCreator && workout.status == .scheduled) || 
                       (workout.status == .active && (isCreator || myParticipation != nil)) {
                        shareSection
                    }
                }
                .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Menu {
                    Button(action: shareWorkout) {
                        Label("Share Workout", systemImage: "square.and.arrow.up")
                    }
                    
                    if isCalendarAdded {
                        Button(action: viewInCalendar) {
                            Label("View in Calendar", systemImage: "calendar")
                        }
                    }
                    
                    Button(action: toggleCalendar) {
                        Label(
                            isCalendarAdded ? "Remove from Calendar" : "Add to Calendar",
                            systemImage: isCalendarAdded ? "calendar.badge.minus" : "calendar.badge.plus"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            )
            .sheet(isPresented: $showInviteSheet) {
                InviteFriendsView(workout: workout)
                    .environment(\.dependencyContainer, container)
            }
            .sheet(isPresented: $showHostProfile) {
                if let hostProfile = hostProfile {
                    ProfileView(userId: hostProfile.userID)
                        .environment(\.dependencyContainer, container)
                }
            }
            .alert("Delete Workout", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteWorkout()
                }
            } message: {
                Text("Are you sure you want to delete this workout? This action cannot be undone.")
            }
            .alert("Added to Calendar", isPresented: $showCalendarSuccessAlert) {
                Button("View in Calendar") {
                    // Open Calendar app to the event date
                    if let url = URL(string: "calshow:\(Int(workout.scheduledStart.timeIntervalSinceReferenceDate))") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Done", role: .cancel) { }
            } message: {
                Text(calendarSuccessMessage)
            }
            .alert("Calendar Access Required", isPresented: $showCalendarDeniedAlert) {
                Button("Not Now", role: .cancel) { }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("To add workouts to your calendar:\n\n1. Tap 'Open Settings'\n2. Turn on 'Calendars'\n3. Return to FameFit\n\nThis lets you get reminders for upcoming group workouts.")
            }
            .task {
                // Get current user ID first
                do {
                    currentUserID = try await container.cloudKitManager.getCurrentUserID()
                } catch {
                    print("Failed to get current user ID: \(error)")
                }
                await loadData()
            }
    }
    
    // MARK: - Sections
    
    private var workoutInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(workout.name)
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 12) {
                Label(workoutTypeName, systemImage: workoutTypeIcon)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if workout.isPublic {
                    Label("Public", systemImage: "globe")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                
                Spacer()
                
                if let myParticipation = myParticipation {
                    statusBadge(myParticipation.status)
                }
            }
            
            // Date & Time
            Label(dateTimeText, systemImage: "calendar")
                .font(.subheadline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            quickActionButtons
        }
    }
    
    @ViewBuilder
    private var quickActionButtons: some View {
        if isCreator {
            if workout.status == .scheduled {
                // Host can start workout anytime when it's scheduled
                Button(action: startWorkout) {
                    Label("Start Workout", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .tint(.green)
            }
            // For active workouts, Complete button is shown in shareSection at bottom
        } else if workout.status == .active && myParticipation != nil {
            // For active workouts, Complete button is shown in shareSection at bottom
            EmptyView()
        } else if myParticipation == nil && workout.isJoinable {
            joinButtons
        } else if let participation = myParticipation, participation.status != .declined {
            statusUpdateButtons(for: participation)
        } else {
            rejoinButton
        }
    }
    
    @ViewBuilder
    private var joinButtons: some View {
        Button(action: { joinWorkout(.joined) }) {
            Label("Join", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(BorderedProminentButtonStyle())
        
        Button(action: { joinWorkout(.maybe) }) {
            Label("Maybe", systemImage: "questionmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(BorderedButtonStyle())
    }
    
    @ViewBuilder
    private func statusUpdateButtons(for participation: GroupWorkoutParticipant) -> some View {
        ForEach(ParticipantStatus.allCases.filter { $0 != .pending }, id: \.self) { status in
            statusButton(for: status, currentStatus: participation.status)
        }
    }
    
    @ViewBuilder
    private func statusButton(for status: ParticipantStatus, currentStatus: ParticipantStatus) -> some View {
        if currentStatus == status {
            Button(action: { updateStatus(status) }) {
                Text(status.displayName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BorderedProminentButtonStyle())
        } else {
            Button(action: { updateStatus(status) }) {
                Text(status.displayName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(BorderedButtonStyle())
        }
    }
    
    @ViewBuilder
    private var rejoinButton: some View {
        Button(action: { joinWorkout(.joined) }) {
            Label("Join Workout", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(BorderedProminentButtonStyle())
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let location = workout.location {
                HStack(alignment: .top) {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                    }
                }
            }
            
            if let notes = workout.notes {
                HStack(alignment: .top) {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(notes)
                    }
                }
            }
            
            if !workout.tags.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "tag")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(workout.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Host section
            if let hostProfile = hostProfile {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Host")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Button(action: { showHostProfile = true }) {
                        HStack {
                            // Avatar
                            if let avatarURL = hostProfile.profileImageURL, let url = URL(string: avatarURL) {
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
                            
                            // Name
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(hostProfile.username)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    
                                    if hostProfile.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                
                                Text("Organizer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Divider()
                    .padding(.vertical, 8)
            }
            
            // Participants header
            HStack {
                Text("Participants (\(acceptedCount)/\(workout.maxParticipants))")
                    .font(.headline)
                
                Spacer()
                
                if isCreator && (workout.status == .scheduled || workout.status == .active) {
                    Button(action: { showInviteSheet = true }) {
                        Label("Invite", systemImage: "person.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)
                }
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if participants.isEmpty {
                Text("No participants yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(participants.sorted(by: { $0.joinedAt < $1.joinedAt })) { participant in
                    // Skip the host in participants list
                    if participant.userId != workout.hostId,
                       let profile = participantProfiles[participant.userId] {
                        ParticipantRow(participant: participant, profile: profile, isCreator: false)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var shareSection: some View {
        Group {
            VStack(spacing: 12) {
                if workout.status == .active {
                    // Complete button for active workouts (both host and participants)
                    Button(action: completeWorkout) {
                        Label("Complete Workout", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .tint(.green)
                } else if isCreator && workout.status == .scheduled {
                    // Cancel button only for scheduled workouts
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        Label("Cancel Workout", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .tint(.red)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func statusBadge(_ status: ParticipantStatus) -> some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .cornerRadius(6)
    }
    
    private func statusColor(_ status: ParticipantStatus) -> Color {
        switch status {
        case .joined: return .green
        case .declined: return .red
        case .maybe: return .orange
        case .pending: return .gray
        case .active: return .blue
        case .completed: return .purple
        case .dropped: return .red.opacity(0.6)
        }
    }
    
    // MARK: - Computed Properties
    
    private var workoutTypeName: String {
        workout.workoutType.displayName
    }
    
    private var workoutTypeIcon: String {
        workout.workoutType.iconName
    }
    
    private var dateTimeText: String {
        let formatter = DateFormatter()
        formatter.timeZone = .current
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: workout.scheduledStart)
    }
    
    private func timeRemainingText(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // MARK: - Actions
    
    private func loadData() async {
        isLoading = true
        
        do {
            // Refresh the workout data itself to get latest status
            let refreshedWorkout = try await container.groupWorkoutService.fetchWorkout(workout.id)
            
            // Load participants
            let loadedParticipants = try await container.groupWorkoutService.getParticipants(workout.id)
            
            // Find my participation
            let currentUserId = try await container.cloudKitManager.getCurrentUserID()
            let myPart = loadedParticipants.first { $0.userId == currentUserId }
            
            // Load host profile
            let hostProf = try? await container.userProfileService.fetchProfileByUserID(workout.hostId)
            
            // Load profiles for participants
            var profiles: [String: UserProfile] = [:]
            for participant in loadedParticipants {
                if let profile = try? await container.userProfileService.fetchProfileByUserID(participant.userId) {
                    profiles[participant.userId] = profile
                }
            }
            
            // Check calendar status
            let calendarKey = "calendar_event_\(workout.id)"
            let hasCalendarEvent = UserDefaults.standard.string(forKey: calendarKey) != nil
            
            await MainActor.run {
                self.workout = refreshedWorkout
                self.participants = loadedParticipants
                self.participantProfiles = profiles
                self.hostProfile = hostProf
                self.myParticipation = myPart
                self.isCalendarAdded = hasCalendarEvent
                self.isLoading = false
            }
        } catch {
            print("Failed to load workout data: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func joinWorkout(_ status: ParticipantStatus) {
        Task {
            do {
                try await container.groupWorkoutService.updateParticipantStatus(workout.id, status: status)
                await loadData()
            } catch {
                print("Failed to join workout: \(error)")
            }
        }
    }
    
    private func updateStatus(_ status: ParticipantStatus) {
        Task {
            do {
                try await container.groupWorkoutService.updateParticipantStatus(workout.id, status: status)
                await loadData()
            } catch {
                print("Failed to update status: \(error)")
            }
        }
    }
    
    private func startWorkout() {
        Task {
            do {
                let updatedWorkout = try await container.groupWorkoutService.startGroupWorkout(workout.id)
                await MainActor.run {
                    self.workout = updatedWorkout
                }
                await loadData()
                
                // TODO: Navigate to watch workout view or show active workout UI
                FameFitLogger.info("🏋️ Started group workout: \(workout.name)", category: FameFitLogger.ui)
            } catch {
                FameFitLogger.error("Failed to start workout", error: error, category: FameFitLogger.ui)
            }
        }
    }
    
    private func completeWorkout() {
        Task {
            do {
                let updatedWorkout = try await container.groupWorkoutService.completeGroupWorkout(workout.id)
                await MainActor.run {
                    self.workout = updatedWorkout
                }
                await loadData()
                
                FameFitLogger.info("🏋️ Completed group workout: \(workout.name)", category: FameFitLogger.ui)
            } catch {
                FameFitLogger.error("Failed to complete workout", error: error, category: FameFitLogger.ui)
            }
        }
    }
    
    private func deleteWorkout() {
        Task {
            do {
                try await container.groupWorkoutService.deleteGroupWorkout(workout.id)
                await MainActor.run {
                    // Post notification for list refresh
                    NotificationCenter.default.post(
                        name: Notification.Name("GroupWorkoutDeleted"),
                        object: nil,
                        userInfo: ["workoutId": workout.id]
                    )
                    onDelete?()  // Notify parent view that workout was deleted (if provided)
                    dismiss()
                }
            } catch {
                print("Failed to delete workout: \(error)")
            }
        }
    }
    
    private func shareWorkout() {
        // Use the workout's built-in sharing functionality which includes the deep link
        let activityVC = UIActivityViewController(
            activityItems: workout.activityItems,
            applicationActivities: nil
        )
        
        // Get the window scene and root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func toggleCalendar() {
        Task {
            do {
                if isCalendarAdded {
                    try await container.groupWorkoutService.removeFromCalendar(workout)
                    await MainActor.run {
                        isCalendarAdded = false
                        calendarSuccessMessage = "Workout removed from your calendar."
                        showCalendarSuccessAlert = true
                    }
                } else {
                    try await container.groupWorkoutService.addToCalendar(workout)
                    await MainActor.run {
                        isCalendarAdded = true
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .short
                        calendarSuccessMessage = "Workout added to your calendar for \(formatter.string(from: workout.scheduledStart)). You'll get a reminder 15 minutes before."
                        showCalendarSuccessAlert = true
                    }
                }
            } catch {
                print("Calendar operation failed: \(error)")
                
                // Check if it's a permission denied error
                if case GroupWorkoutError.calendarAccessDenied = error {
                    await MainActor.run {
                        showCalendarDeniedAlert = true
                    }
                }
            }
        }
    }
    
    private func viewInCalendar() {
        // Open Calendar app to the event date
        // Using calshow URL scheme with the event date
        if let url = URL(string: "calshow:\(Int(workout.scheduledStart.timeIntervalSinceReferenceDate))") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Participant Row

struct ParticipantRow: View {
    let participant: GroupWorkoutParticipant
    let profile: UserProfile
    let isCreator: Bool
    
    var body: some View {
        HStack {
            // Avatar
            if let avatarURL = profile.profileImageURL, let url = URL(string: avatarURL) {
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
            
            // Name and status
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(profile.username)
                        .font(.subheadline)
                    
                    if profile.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                
                Text(participant.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct InviteFriendsView: View {
    let workout: GroupWorkout
    @Environment(\.dependencyContainer) private var container
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedUsers: Set<String> = []
    @State private var isLoading = false
    @State private var followers: [UserProfile] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if workout.joinCode != nil {
                    joinCodeSection
                }
                
                searchBar
                
                // Followers list
                followersContent
            }
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendInvites()
                    }
                    .disabled(selectedUsers.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .task {
                await loadFollowers()
            }
        }
    }
    
    private var filteredFollowers: [UserProfile] {
        if searchText.isEmpty {
            return followers
        }
        return followers.filter { user in
            user.username.localizedCaseInsensitiveContains(searchText) ||
            user.bio.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func loadFollowers() async {
        isLoading = true
        do {
            // Get current user's followers
            if let userId = container.cloudKitManager.currentUserID {
                followers = try await container.socialFollowingService.getFollowers(for: userId, limit: 50)
            }
        } catch {
            errorMessage = "Failed to load followers"
            showingError = true
        }
        isLoading = false
    }
    
    private func sendInvites() {
        // TODO: Implement invite sending via notifications
        // For now, just dismiss
        dismiss()
    }
    
    // MARK: - View Components
    
    private var joinCodeSection: some View {
        VStack(spacing: 12) {
            Text("Share Join Code")
                .font(.headline)
            
            Text(workout.joinCode ?? "")
                .font(.system(.largeTitle, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                )
            
            Button(action: {
                UIPasteboard.general.string = workout.joinCode
                // TODO: Show toast/confirmation
            }) {
                Label("Copy Code", systemImage: "doc.on.doc")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            
            Divider()
                .padding(.vertical)
        }
        .padding()
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search followers", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
    
    @ViewBuilder
    private var followersContent: some View {
        if isLoading {
            ProgressView("Loading followers...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredFollowers.isEmpty {
            emptyFollowersView
        } else {
            followersList
        }
    }
    
    private var emptyFollowersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No followers found")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var followersList: some View {
        List {
            ForEach(filteredFollowers) { user in
                InviteFollowerRow(
                    user: user,
                    isSelected: selectedUsers.contains(user.id),
                    onTap: {
                        if selectedUsers.contains(user.id) {
                            selectedUsers.remove(user.id)
                        } else {
                            selectedUsers.insert(user.id)
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Invite Follower Row Component

private struct InviteFollowerRow: View {
    let user: UserProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            // Profile image
            profileImage
            
            // User info
            userInfo
            
            Spacer()
            
            // Selection checkmark
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 24))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    @ViewBuilder
    private var profileImage: some View {
        if let imageURL = user.profileImageURL {
            AsyncImage(url: URL(string: imageURL)) { image in
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
    }
    
    private var userInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(user.username)
                .font(.system(size: 16, weight: .medium))
            if !user.bio.isEmpty {
                Text(user.bio)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

