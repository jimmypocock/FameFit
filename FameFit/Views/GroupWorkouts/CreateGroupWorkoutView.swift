//
//  CreateGroupWorkoutView.swift
//  FameFit
//
//  View for creating a new group workout
//

import SwiftUI
import EventKit
import HealthKit

struct CreateGroupWorkoutView: View {
    @Environment(\.dependencyContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigationCoordinator) private var navigationCoordinator
    
    @State private var title = ""
    @State private var selectedWorkoutType: Int = 37 // Running
    @State private var scheduledDate = Date().addingTimeInterval(300) // 5 minutes from now
    @State private var location = ""
    @State private var notes = ""
    @State private var maxParticipants = GroupWorkoutConstants.defaultMaxParticipants
    @State private var isPublic = false
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var addToCalendar = false
    
    @State private var isCreating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = "Group workout created successfully!"
    
    // Timezone handling
    @State private var selectedTimeZone = TimeZone.current
    @State private var showTimeZonePicker = false
    
    init() {
        FameFitLogger.debug("📝 CreateGroupWorkoutView initialized", category: FameFitLogger.ui)
    }
    
    private let workoutTypes: [(id: Int, name: String, icon: String)] = [
        (37, "Running", "figure.run"),
        (13, "Cycling", "bicycle"),
        (46, "Swimming", "figure.pool.swim"),
        (20, "Functional Training", "figure.strengthtraining.functional"),
        (71, "Yoga", "figure.yoga"),
        (16, "Dance", "figure.dance"),
        (35, "Racquetball", "figure.racquetball"),
        (52, "Tennis", "figure.tennis"),
        (24, "Hiking", "figure.hiking"),
        (15, "Crossfit", "figure.cross.training")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Info
                Section {
                    TextField("Workout Title", text: $title)
                    
                    Picker("Workout Type", selection: $selectedWorkoutType) {
                        ForEach(workoutTypes, id: \.id) { type in
                            Label(type.name, systemImage: type.icon)
                                .tag(type.id)
                        }
                    }
                }
                
                // Schedule
                Section {
                    DatePicker("Date & Time", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Time Zone")
                        Spacer()
                        Button(action: { showTimeZonePicker = true }) {
                            Text(selectedTimeZone.identifier.replacingOccurrences(of: "_", with: " "))
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                // Location & Details
                Section {
                    TextField("Location (optional)", text: $location)
                    
                    VStack(alignment: .leading) {
                        Text("Notes (optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(minHeight: 60)
                            .onAppear {
                                FameFitLogger.debug("📝 TextEditor appeared with minHeight: 60", category: FameFitLogger.ui)
                            }
                            .onChange(of: notes) { _, newValue in
                                FameFitLogger.debug("📝 Notes changed, length: \(newValue.count)", category: FameFitLogger.ui)
                            }
                    }
                }
                
                // Settings
                Section {
                    Toggle("Make Public", isOn: $isPublic)
                    
                    if isPublic {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Participants")
                                Spacer()
                                TextField("", value: $maxParticipants, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .onChange(of: maxParticipants) { _, newValue in
                                        // Enforce limits
                                        if newValue < GroupWorkoutConstants.minParticipants {
                                            maxParticipants = GroupWorkoutConstants.minParticipants
                                        } else if newValue > GroupWorkoutConstants.maxParticipantsLimit {
                                            maxParticipants = GroupWorkoutConstants.maxParticipantsLimit
                                        }
                                        FameFitLogger.debug("📝 Max participants changed to: \(maxParticipants)", category: FameFitLogger.ui)
                                    }
                            }
                            Text("Max participants must be between \(GroupWorkoutConstants.minParticipants)-\(GroupWorkoutConstants.maxParticipantsLimit).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("Add tag", text: $tagInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .onSubmit {
                                        addTag()
                                    }
                                
                                Button("Add", action: addTag)
                                    .disabled(tagInput.isEmpty)
                            }
                            
                            if !tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(tags, id: \.self) { tag in
                                            HStack(spacing: 4) {
                                                Text("#\(tag)")
                                                Button(action: { removeTag(tag) }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.caption)
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.1))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Add to Calendar", isOn: $addToCalendar)
                        if addToCalendar {
                            Text("Will add to your device calendar with a 30-minute reminder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Create Group Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Create") {
                    createWorkout()
                }
                .disabled(title.isEmpty || isCreating)
            )
            .sheet(isPresented: $showTimeZonePicker) {
                TimeZonePickerView(selectedTimeZone: $selectedTimeZone)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Creating workout...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .onAppear {
                                    FameFitLogger.debug("📝 ProgressView appeared", category: FameFitLogger.ui)
                                }
                        }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) && tags.count < 5 {
            tags.append(trimmedTag)
            tagInput = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    private func createWorkout() {
        guard !title.isEmpty else { 
            FameFitLogger.warning("📝 Attempted to create workout with empty title", category: FameFitLogger.ui)
            return 
        }
        
        FameFitLogger.debug("📝 createWorkout called with state:", category: FameFitLogger.ui)
        FameFitLogger.debug("  - title: \(title)", category: FameFitLogger.ui)
        FameFitLogger.debug("  - selectedWorkoutType: \(selectedWorkoutType)", category: FameFitLogger.ui)
        FameFitLogger.debug("  - scheduledDate: \(scheduledDate)", category: FameFitLogger.ui)
        FameFitLogger.debug("  - maxParticipants: \(maxParticipants)", category: FameFitLogger.ui)
        FameFitLogger.debug("  - isPublic: \(isPublic)", category: FameFitLogger.ui)
        FameFitLogger.debug("  - tags: \(tags)", category: FameFitLogger.ui)
        FameFitLogger.debug("  - location: \(location)", category: FameFitLogger.ui)
        FameFitLogger.debug("  - notes length: \(notes.count)", category: FameFitLogger.ui)
        
        isCreating = true
        FameFitLogger.info("Starting group workout creation: \(title)", category: FameFitLogger.social)
        
        Task {
            do {
                // Get current user ID
                let currentUserID = container.cloudKitManager.currentUserID ?? "unknown"
                FameFitLogger.debug("Creating workout with userID: \(currentUserID)", category: FameFitLogger.social)
                
                // Create the workout
                let workoutType = HKWorkoutActivityType(rawValue: UInt(selectedWorkoutType)) ?? .running
                let scheduledEnd = scheduledDate.addingTimeInterval(3_600) // Default 1 hour duration
                
                let workout = GroupWorkout(
                    name: title,
                    description: notes,
                    workoutType: workoutType,
                    hostID: currentUserID,
                    maxParticipants: maxParticipants,
                    scheduledStart: scheduledDate,
                    scheduledEnd: scheduledEnd,
                    isPublic: isPublic,
                    tags: tags,
                    location: location.isEmpty ? nil : location,
                    notes: notes.isEmpty ? nil : notes
                )
                
                let createdWorkout = try await container.groupWorkoutService.createGroupWorkout(workout)
                
                FameFitLogger.info("✅ Group workout created successfully: \(createdWorkout.id)", category: FameFitLogger.social)
                
                // Add to calendar if requested
                if addToCalendar {
                    do {
                        try await container.groupWorkoutService.addToCalendar(createdWorkout)
                        FameFitLogger.info("✅ Added workout to calendar", category: FameFitLogger.social)
                    } catch {
                        // Calendar addition failed, but workout was created
                        FameFitLogger.warning("Failed to add workout to calendar: \(error.localizedDescription)", category: FameFitLogger.general)
                    }
                }
                
                await MainActor.run {
                    FameFitLogger.debug("📝 Dismissing CreateGroupWorkoutView after successful creation", category: FameFitLogger.ui)
                    isCreating = false
                    
                    // Dismiss sheet first
                    dismiss()
                    
                    // Navigate after a longer delay to ensure sheet is fully dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        FameFitLogger.info("Navigating to created workout: \(createdWorkout.id)", category: FameFitLogger.ui)
                        navigationCoordinator?.navigateToGroupWorkout(createdWorkout)
                    }
                }
            } catch {
                FameFitLogger.error("Failed to create group workout", error: error, category: FameFitLogger.social)
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Time Zone Picker

struct TimeZonePickerView: View {
    @Binding var selectedTimeZone: TimeZone
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var timeZones: [TimeZone] {
        TimeZone.knownTimeZoneIdentifiers.compactMap { TimeZone(identifier: $0) }
    }
    
    private var filteredTimeZones: [TimeZone] {
        if searchText.isEmpty {
            return timeZones
        }
        return timeZones.filter { zone in
            zone.identifier.localizedCaseInsensitiveContains(searchText) ||
            zone.localizedName(for: .standard, locale: .current)?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredTimeZones, id: \.identifier) { zone in
                    Button(action: {
                        selectedTimeZone = zone
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(zone.identifier.replacingOccurrences(of: "_", with: " "))
                                    .foregroundColor(.primary)
                                
                                if let name = zone.localizedName(for: .standard, locale: .current) {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(zone.abbreviation() ?? "")
                                .foregroundColor(.secondary)
                            
                            if zone.identifier == selectedTimeZone.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search time zones")
            .navigationTitle("Select Time Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
