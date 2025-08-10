//
//  CreateChallengeView.swift
//  FameFit
//
//  View for creating new workout challenges
//

import SwiftUI

struct CreateChallengeView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container

    @State private var challengeType: ChallengeType = .distance
    @State private var challengeName = ""
    @State private var challengeDescription = ""
    @State private var targetValue = ""
    @State private var selectedWorkoutType = "Running"
    @State private var duration: Int = 7 // days
    @State private var xpStake = ""
    @State private var winnerTakesAll = false
    @State private var isPublic = true
    @State private var maxParticipants = "10"
    @State private var selectedFriends: Set<String> = []
    @State private var showingFriendPicker = false
    @State private var isCreating = false
    @State private var error: String?

    private let workoutTypes = [
        "Running", "Walking", "Cycling", "Swimming", "Strength Training",
        "Yoga", "HIIT", "Dance", "Rowing", "Elliptical"
    ]

    private let durationOptions = [
        (3, "3 days"),
        (7, "1 week"),
        (14, "2 weeks"),
        (30, "1 month")
    ]

    private var isValid: Bool {
        !challengeName.isEmpty &&
            !targetValue.isEmpty &&
            Double(targetValue) ?? 0 > 0 &&
            (isPublic || !selectedFriends.isEmpty) &&
            Int(maxParticipants) ?? 0 > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Challenge Type
                Section("Challenge Type") {
                    Picker("Type", selection: $challengeType) {
                        ForEach(ChallengeType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: "")
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: challengeType) {
                        updateDefaultValues()
                    }

                    if challengeType == .specificWorkout {
                        Picker("Workout Type", selection: $selectedWorkoutType) {
                            ForEach(workoutTypes, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                    }
                }

                // Challenge Details
                Section("Details") {
                    TextField("Challenge Name", text: $challengeName)

                    TextField("Description (optional)", text: $challengeDescription, axis: .vertical)
                        .lineLimit(2 ... 4)

                    HStack {
                        TextField("Target", text: $targetValue)
                            .keyboardType(.decimalPad)

                        Text(challengeType.unit)
                            .foregroundColor(.secondary)
                    }

                    Picker("Duration", selection: $duration) {
                        ForEach(durationOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                }

                // Participants
                if !isPublic {
                    Section("Participants") {
                        Button(action: {
                            showingFriendPicker = true
                        }) {
                            HStack {
                                Text("Select Friends to Invite")
                                Spacer()
                                if selectedFriends.isEmpty {
                                    Text("Required")
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(selectedFriends.count) selected")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Stakes (Optional)
                Section("Stakes (Optional)") {
                    HStack {
                        TextField("XP Stake", text: $xpStake)
                            .keyboardType(.numberPad)

                        Text("XP per person")
                            .foregroundColor(.secondary)
                    }

                    if !xpStake.isEmpty {
                        Toggle("Winner takes all", isOn: $winnerTakesAll)
                            .tint(.accentColor)
                    }
                }

                // Privacy
                Section("Privacy") {
                    Toggle("Public Challenge", isOn: $isPublic)
                        .tint(.accentColor)

                    if isPublic {
                        HStack {
                            Text("Max Participants")
                            Spacer()
                            TextField("Max", text: $maxParticipants)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        Text("Others can see and join this challenge up to the participant limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Only invited friends can see this challenge. A join code will be generated.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Error message
                if let error {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createChallenge()
                    }
                    .fontWeight(.medium)
                    .disabled(!isValid || isCreating)
                }
            }
            .sheet(isPresented: $showingFriendPicker) {
                FriendPickerView(selectedFriends: $selectedFriends)
            }
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Creating challenge...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                        }
                }
            }
        }
    }

    private func updateDefaultValues() {
        // Set default names based on type
        if challengeName.isEmpty {
            switch challengeType {
            case .distance:
                challengeName = "Distance Challenge"
                targetValue = "50"
            case .duration:
                challengeName = "Duration Challenge"
                targetValue = "300" // 5 hours in minutes
            case .calories:
                challengeName = "Calorie Burn Challenge"
                targetValue = "2000"
            case .workoutCount:
                challengeName = "Workout Count Challenge"
                targetValue = "10"
            case .totalXP:
                challengeName = "XP Challenge"
                targetValue = "500"
            case .specificWorkout:
                challengeName = "\(selectedWorkoutType) Challenge"
                targetValue = "5"
            }
        }
    }

    private func createChallenge() {
        guard let targetValueDouble = Double(targetValue),
              let currentUserID = container.cloudKitManager.currentUserID
        else {
            error = "Invalid input values"
            return
        }

        isCreating = true
        error = nil
        FameFitLogger.info("Creating challenge: \(challengeName)", category: FameFitLogger.social)

        Task {
            do {
                // Get user profiles for selected friends
                var participants = [ChallengeParticipant]()

                // Add creator
                // currentUserID is from cloudKitManager, so it's a CloudKit user ID
                if let creatorProfile = try? await container.userProfileService.fetchProfileByUserID(currentUserID) {
                    participants.append(ChallengeParticipant(
                        id: currentUserID,
                        username: creatorProfile.username,
                        profileImageURL: creatorProfile.profileImageURL
                    ))
                }

                // Add selected friends
                for friendID in selectedFriends {
                    // friendID from selectedFriends - need to check if it's CloudKit ID or profile ID
                    // Since selectedFriends likely comes from social service, it's probably profile IDs
                    if let profile = try? await container.userProfileService.fetchProfile(userID: friendID) {
                        participants.append(ChallengeParticipant(
                            id: friendID,
                            username: profile.username,
                            profileImageURL: profile.profileImageURL
                        ))
                    }
                }

                let challenge = WorkoutChallenge(
                    id: UUID().uuidString,
                    creatorID: currentUserID,
                    participants: participants,
                    type: challengeType,
                    targetValue: targetValueDouble,
                    workoutType: challengeType == .specificWorkout ? selectedWorkoutType : nil,
                    name: challengeName,
                    description: challengeDescription
                        .isEmpty ? "Reach \(Int(targetValueDouble)) \(challengeType.unit) in \(duration) days" :
                        challengeDescription,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(Double(duration) * 24 * 3_600),
                    creationDate: Date(),
                    status: .pending,
                    winnerID: nil,
                    xpStake: Int(xpStake) ?? 0,
                    winnerTakesAll: winnerTakesAll,
                    isPublic: isPublic,
                    maxParticipants: Int(maxParticipants) ?? 10,
                    joinCode: isPublic ? nil : WorkoutChallenge.generateJoinCode()
                )

                FameFitLogger.debug("Saving challenge to CloudKit", category: FameFitLogger.cloudKit)
                _ = try await container.workoutChallengesService.createChallenge(challenge)
                FameFitLogger.info("Challenge created successfully", category: FameFitLogger.social)

                await MainActor.run {
                    dismiss()
                }
            } catch {
                FameFitLogger.error("Failed to create challenge", error: error, category: FameFitLogger.social)
                await MainActor.run {
                    self.error = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Friend Picker View

struct FriendPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var container
    @Binding var selectedFriends: Set<String>

    @State private var friends: [UserProfile] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading friends...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No Friends Yet")
                            .font(.headline)

                        Text("Follow users to invite them to challenges")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(friends) { friend in
                        HStack {
                            // Profile image placeholder
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(friend.initials)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                )

                            VStack(alignment: .leading) {
                                Text(friend.username)
                                    .font(.body)

                                Text("@\(friend.username)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedFriends.contains(friend.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFriends.contains(friend.id) {
                                selectedFriends.remove(friend.id)
                            } else {
                                selectedFriends.insert(friend.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .task {
                await loadFriends()
            }
        }
    }

    private func loadFriends() async {
        guard let currentUserID = container.cloudKitManager.currentUserID else { return }

        do {
            let following = try await container.socialFollowingService.getFollowing(for: currentUserID, limit: 100)
            friends = following
            isLoading = false
        } catch {
            print("Failed to load friends: \(error)")
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    CreateChallengeView()
        .environment(\.dependencyContainer, DependencyContainer())
}
