//
//  GroupWorkoutDetailView.swift
//  FameFit
//
//  Detailed view for a group workout with participants and actions
//

import SwiftUI

struct GroupWorkoutDetailView: View {
    let workout: GroupWorkout
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    
    @State private var participants: [GroupWorkoutParticipant] = []
    @State private var participantProfiles: [String: UserProfile] = [:]
    @State private var myParticipation: GroupWorkoutParticipant?
    @State private var isLoading = true
    @State private var showInviteSheet = false
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var isCalendarAdded = false
    
    private var isCreator: Bool {
        workout.createdBy == container.cloudKitManager.userRecordID?.recordName
    }
    
    private var acceptedCount: Int {
        participants.filter { $0.status == .accepted }.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Quick Actions
                    if workout.isUpcoming {
                        quickActionsSection
                    }
                    
                    // Details
                    detailsSection
                    
                    // Participants
                    participantsSection
                    
                    // Share & Calendar
                    if workout.isUpcoming {
                        shareSection
                    }
                }
                .padding()
            }
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isCreator && workout.isUpcoming {
                        Menu {
                            Button(action: { showEditSheet = true }) {
                                Label("Edit Workout", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: { showDeleteAlert = true }) {
                                Label("Delete Workout", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showInviteSheet) {
                InviteFriendsView(workout: workout)
                    .environmentObject(container)
            }
            .sheet(isPresented: $showEditSheet) {
                EditGroupWorkoutView(workout: workout)
                    .environmentObject(container)
            }
            .alert("Delete Workout", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteWorkout()
                }
            } message: {
                Text("Are you sure you want to delete this workout? This action cannot be undone.")
            }
            .task {
                await loadData()
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
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
                    }
                }
                
                Spacer()
                
                if let myParticipation = myParticipation {
                    statusBadge(myParticipation.status)
                }
            }
            
            // Date & Time with timezone
            VStack(alignment: .leading, spacing: 4) {
                Label(dateTimeText, systemImage: "calendar")
                    .font(.subheadline)
                
                if workout.timeZone != TimeZone.current.identifier {
                    Text("Time Zone: \(workout.timeZone.replacingOccurrences(of: "_", with: " "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            if myParticipation == nil {
                // Join buttons
                Button(action: { joinWorkout(.accepted) }) {
                    Label("Join", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: { joinWorkout(.maybe) }) {
                    Label("Maybe", systemImage: "questionmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else if let participation = myParticipation, participation.status != .declined {
                // Update status buttons
                ForEach(GroupWorkoutParticipant.ParticipantStatus.allCases.filter { $0 != .pending }, id: \.self) { status in
                    Button(action: { updateStatus(status) }) {
                        Text(status.displayName)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(participation.status == status ? .borderedProminent : .bordered)
                }
            } else {
                // Declined - show rejoin option
                Button(action: { joinWorkout(.accepted) }) {
                    Label("Join Workout", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
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
            HStack {
                Text("Participants (\(acceptedCount)/\(workout.maxParticipants))")
                    .font(.headline)
                
                Spacer()
                
                if isCreator && workout.isUpcoming {
                    Button(action: { showInviteSheet = true }) {
                        Label("Invite", systemImage: "person.badge.plus")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
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
                    if let profile = participantProfiles[participant.userProfileId] {
                        ParticipantRow(participant: participant, profile: profile, isCreator: isCreator)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var shareSection: some View {
        VStack(spacing: 12) {
            Button(action: shareWorkout) {
                Label("Share Workout", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: toggleCalendar) {
                Label(
                    isCalendarAdded ? "Remove from Calendar" : "Add to Calendar",
                    systemImage: isCalendarAdded ? "calendar.badge.minus" : "calendar.badge.plus"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Helper Views
    
    private func statusBadge(_ status: GroupWorkoutParticipant.ParticipantStatus) -> some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .cornerRadius(6)
    }
    
    private func statusColor(_ status: GroupWorkoutParticipant.ParticipantStatus) -> Color {
        switch status {
        case .accepted: return .green
        case .declined: return .red
        case .maybe: return .orange
        case .pending: return .gray
        }
    }
    
    // MARK: - Computed Properties
    
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
    
    private var dateTimeText: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: workout.timeZone) ?? .current
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: workout.scheduledDate)
    }
    
    // MARK: - Actions
    
    private func loadData() async {
        isLoading = true
        
        do {
            // Load participants
            let loadedParticipants = try await container.groupWorkoutSchedulingService.getParticipants(workout.id)
            
            // Find my participation
            let currentUserId = try await container.cloudKitManager.getCurrentUserID()
            let myPart = loadedParticipants.first { $0.userId == currentUserId }
            
            // Load profiles for participants
            var profiles: [String: UserProfile] = [:]
            for participant in loadedParticipants {
                if let profile = try? await container.userProfileService.fetchProfileByUserID(participant.userProfileId) {
                    profiles[participant.userProfileId] = profile
                }
            }
            
            // Check calendar status
            let calendarKey = "calendar_\(workout.id)"
            let hasCalendarEvent = UserDefaults.standard.string(forKey: calendarKey) != nil
            
            await MainActor.run {
                self.participants = loadedParticipants
                self.participantProfiles = profiles
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
    
    private func joinWorkout(_ status: GroupWorkoutParticipant.ParticipantStatus) {
        Task {
            do {
                try await container.groupWorkoutSchedulingService.joinGroupWorkout(workout.id, status: status)
                await loadData()
            } catch {
                print("Failed to join workout: \(error)")
            }
        }
    }
    
    private func updateStatus(_ status: GroupWorkoutParticipant.ParticipantStatus) {
        Task {
            do {
                try await container.groupWorkoutSchedulingService.updateParticipantStatus(workout.id, status: status)
                await loadData()
            } catch {
                print("Failed to update status: \(error)")
            }
        }
    }
    
    private func deleteWorkout() {
        Task {
            do {
                try await container.groupWorkoutSchedulingService.deleteGroupWorkout(workout.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to delete workout: \(error)")
            }
        }
    }
    
    private func shareWorkout() {
        let message = "Join me for \(workout.title) on \(dateTimeText)"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func toggleCalendar() {
        Task {
            do {
                if isCalendarAdded {
                    try await container.groupWorkoutSchedulingService.removeFromCalendar(workout)
                } else {
                    try await container.groupWorkoutSchedulingService.addToCalendar(workout)
                }
                
                await MainActor.run {
                    isCalendarAdded.toggle()
                }
            } catch {
                print("Calendar operation failed: \(error)")
            }
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
            if let avatarURL = profile.avatarURL, let url = URL(string: avatarURL) {
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
                    Text(profile.displayName)
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
            
            // Creator badge
            if participant.userId == profile.cloudKitUserID && isCreator {
                Text("Organizer")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

struct InviteFriendsView: View {
    let workout: GroupWorkout
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Invite Friends - Coming Soon")
                .navigationTitle("Invite Friends")
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
}

struct EditGroupWorkoutView: View {
    let workout: GroupWorkout
    @EnvironmentObject private var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Edit Workout - Coming Soon")
                .navigationTitle("Edit Workout")
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
}