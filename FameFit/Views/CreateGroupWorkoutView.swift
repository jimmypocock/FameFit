//
//  CreateGroupWorkoutView.swift
//  FameFit
//
//  View for creating new group workout sessions
//

import SwiftUI
import HealthKit

struct CreateGroupWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencyContainer) private var container
    
    @State private var workoutName = ""
    @State private var workoutDescription = ""
    @State private var selectedWorkoutType: HKWorkoutActivityType = .running
    @State private var selectedDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var duration: TimeInterval = 3600 // 1 hour default
    @State private var maxParticipants = 8
    @State private var isPublic = true
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var showingTagInput = false
    
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    private let workoutTypes: [HKWorkoutActivityType] = [
        .running, .walking, .hiking, .cycling, .swimming,
        .functionalStrengthTraining, .traditionalStrengthTraining,
        .yoga, .pilates, .boxing, .kickboxing
    ]
    
    private let durationOptions: [(String, TimeInterval)] = [
        ("30 min", 1800),
        ("45 min", 2700), 
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200),
        ("3 hours", 10800)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Basic Info Section
                    basicInfoSection
                    
                    // Workout Details Section
                    workoutDetailsSection
                    
                    // Schedule Section
                    scheduleSection
                    
                    // Participants Section
                    participantsSection
                    
                    // Privacy Section
                    privacySection
                    
                    // Tags Section
                    tagsSection
                    
                    // Create Button
                    createButton
                }
                .padding()
            }
            .navigationTitle("Create Group Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Basic Information", icon: "info.circle")
            
            VStack(spacing: 16) {
                // Workout Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    TextField("e.g., Morning Run Club", text: $workoutName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.next)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    TextField("Optional description...", text: $workoutDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - Workout Details Section
    
    private var workoutDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Workout Details", icon: "figure.run")
            
            VStack(spacing: 16) {
                // Workout Type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout Type")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(workoutTypes, id: \.self) { type in
                                WorkoutTypeButton(
                                    type: type,
                                    isSelected: selectedWorkoutType == type,
                                    action: { selectedWorkoutType = type }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                // Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(durationOptions, id: \.0) { option in
                            Button(action: { duration = option.1 }) {
                                Text(option.0)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(duration == option.1 ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(duration == option.1 ? Color.blue : Color(.systemGray5))
                                    )
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - Schedule Section
    
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Schedule", icon: "calendar")
            
            VStack(spacing: 16) {
                DatePicker(
                    "Start Time",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                
                HStack {
                    Text("End Time:")
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Text(endDate, style: .time)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - Participants Section
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Participants", icon: "person.2")
            
            VStack(spacing: 16) {
                HStack {
                    Text("Maximum Participants")
                        .font(.system(size: 16, weight: .medium))
                    
                    Spacer()
                    
                    Stepper(
                        value: $maxParticipants,
                        in: 2...50,
                        step: 1
                    ) {
                        Text("\(maxParticipants)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                
                Text("Including yourself as the host")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Privacy", icon: "lock.shield")
            
            VStack(spacing: 16) {
                Toggle(isOn: $isPublic) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Public Workout")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text(isPublic ? "Anyone can find and join this workout" : "Only people with the join code can participate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Tags", icon: "tag")
            
            VStack(alignment: .leading, spacing: 16) {
                // Existing tags
                if !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagView(
                                text: tag,
                                onRemove: { removeTag(tag) }
                            )
                        }
                    }
                }
                
                // Add tag button
                Button(action: { showingTagInput = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14))
                        Text("Add Tag")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue, lineWidth: 1)
                    )
                }
                
                Text("Tags help others find your workout (e.g., Beginner, Outdoor, HIIT)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
        .alert("Add Tag", isPresented: $showingTagInput) {
            TextField("Tag name", text: $newTag)
            Button("Add") {
                addTag()
            }
            Button("Cancel", role: .cancel) {
                newTag = ""
            }
        } message: {
            Text("Enter a short tag to help categorize this workout")
        }
    }
    
    // MARK: - Create Button
    
    private var createButton: some View {
        Button(action: createWorkout) {
            HStack(spacing: 12) {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                }
                
                Text(isCreating ? "Creating..." : "Create Group Workout")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canCreate ? Color.blue : Color.gray)
            )
        }
        .disabled(!canCreate || isCreating)
    }
    
    // MARK: - Helper Views
    
    private struct SectionHeader: View {
        let title: String
        let icon: String
        
        var body: some View {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
    }
    
    private struct WorkoutTypeButton: View {
        let type: HKWorkoutActivityType
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: iconForWorkoutType(type))
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Text(nameForWorkoutType(type))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(width: 80, height: 80)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
            }
        }
        
        private func iconForWorkoutType(_ type: HKWorkoutActivityType) -> String {
            switch type {
            case .running: return "figure.run"
            case .walking: return "figure.walk"
            case .hiking: return "figure.hiking"
            case .cycling: return "bicycle"
            case .swimming: return "figure.pool.swim"
            case .functionalStrengthTraining: return "dumbbell"
            case .traditionalStrengthTraining: return "dumbbell.fill"
            case .yoga: return "figure.yoga"
            case .pilates: return "figure.pilates"
            case .dance: return "figure.dance"
            case .boxing: return "figure.boxing"
            case .kickboxing: return "figure.kickboxing"
            default: return "figure.mixed.cardio"
            }
        }
        
        private func nameForWorkoutType(_ type: HKWorkoutActivityType) -> String {
            switch type {
            case .running: return "Running"
            case .walking: return "Walking"
            case .hiking: return "Hiking"
            case .cycling: return "Cycling"
            case .swimming: return "Swimming"
            case .functionalStrengthTraining: return "Strength"
            case .traditionalStrengthTraining: return "Weights"
            case .yoga: return "Yoga"
            case .pilates: return "Pilates"
            case .dance: return "Dance"
            case .boxing: return "Boxing"
            case .kickboxing: return "Kickboxing"
            default: return "Workout"
            }
        }
    }
    
    private struct TagView: View {
        let text: String
        let onRemove: () -> Void
        
        var body: some View {
            HStack(spacing: 4) {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var endDate: Date {
        selectedDate.addingTimeInterval(duration)
    }
    
    private var canCreate: Bool {
        !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedDate > Date() &&
        duration > 0 &&
        maxParticipants >= 2
    }
    
    // MARK: - Actions
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) && tags.count < 5 {
            tags.append(trimmedTag)
        }
        newTag = ""
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    private func createWorkout() {
        guard canCreate else { return }
        
        isCreating = true
        
        Task {
            do {
                let groupWorkout = GroupWorkout(
                    name: workoutName,
                    description: workoutDescription,
                    workoutType: selectedWorkoutType,
                    hostId: container.cloudKitManager.currentUserID ?? "",
                    maxParticipants: maxParticipants,
                    scheduledStart: selectedDate,
                    scheduledEnd: endDate,
                    isPublic: isPublic,
                    tags: tags
                )
                
                _ = try await container.groupWorkoutService.createGroupWorkout(groupWorkout)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return layout(sizes: sizes, spacing: spacing, containerWidth: proposal.width ?? 0).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = layout(sizes: sizes, spacing: spacing, containerWidth: bounds.width).offsets
        
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }
    
    private func layout(sizes: [CGSize], spacing: CGFloat, containerWidth: CGFloat) -> (offsets: [CGPoint], size: CGSize) {
        var result: [CGPoint] = []
        var currentPosition = CGPoint.zero
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for size in sizes {
            if currentPosition.x + size.width > containerWidth && !result.isEmpty {
                currentPosition.x = 0
                currentPosition.y += lineHeight + spacing
                lineHeight = 0
            }
            
            result.append(currentPosition)
            currentPosition.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentPosition.x - spacing)
        }
        
        return (result, CGSize(width: maxX, height: currentPosition.y + lineHeight))
    }
}

// MARK: - Preview

#Preview {
    CreateGroupWorkoutView()
}