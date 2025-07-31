//
//  WorkoutCard.swift
//  FameFit
//
//  Enhanced workout card with social interactions
//

import HealthKit
import SwiftUI

struct WorkoutCard: View {
    let workout: Workout
    let userProfile: UserProfile?
    let kudosSummary: WorkoutKudosSummary?
    let onKudosTap: () async -> Void
    let onProfileTap: () -> Void
    let onShareTap: () -> Void

    @State private var isExpanded = false
    @State private var showKudosList = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with user info
            if let profile = userProfile {
                HStack(spacing: 12) {
                    // Profile image
                    AsyncImage(url: profile.profileImageURL.flatMap { URL(string: $0) }) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Text(profile.username.prefix(1))
                                    .font(.system(size: 18, weight: .medium))
                            )
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .onTapGesture {
                        onProfileTap()
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(profile.username)
                                .font(.system(size: 16, weight: .semibold))

                            if profile.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        }

                        Text("@\(profile.username)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Workout time
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(workout.startDate, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            // Workout content
            VStack(alignment: .leading, spacing: 12) {
                // Workout type and XP
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: workoutIcon(for: workout.workoutType))
                            .font(.system(size: 24))
                            .foregroundColor(.blue)

                        Text(workout.workoutType)
                            .font(.system(size: 20, weight: .semibold))
                    }

                    Spacer()

                    Text("+\(workout.effectiveXPEarned) XP")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                }

                // Workout stats
                HStack(spacing: 16) {
                    StatBadge(
                        icon: "clock",
                        value: workout.formattedDuration,
                        color: .orange
                    )

                    StatBadge(
                        icon: "flame",
                        value: workout.formattedCalories,
                        color: .red
                    )

                    if let distance = workout.formattedDistance {
                        StatBadge(
                            icon: "location",
                            value: distance,
                            color: .blue
                        )
                    }

                    if let heartRate = workout.averageHeartRate {
                        StatBadge(
                            icon: "heart",
                            value: "\(Int(heartRate)) bpm",
                            color: .pink
                        )
                    }
                }

                // Expanded details
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()

                        HStack {
                            Label("Started", systemImage: "play.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(workout.startDate, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Label("Ended", systemImage: "stop.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(workout.endDate, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Label("Source", systemImage: "app.badge")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(workout.source)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            // Interaction bar
            HStack(spacing: 20) {
                // Kudos button
                KudosButton(
                    workoutId: workout.id.uuidString,
                    ownerId: userProfile?.id ?? "",
                    kudosSummary: kudosSummary,
                    onTap: onKudosTap
                )
                .onTapGesture {
                    if (kudosSummary?.totalCount ?? 0) > 0 {
                        showKudosList = true
                    }
                }

                // Share button
                Button(action: onShareTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))

                        Text("Share")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.1))
                    )
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .sheet(isPresented: $showKudosList) {
            if let summary = kudosSummary {
                NavigationView {
                    KudosListView(kudosSummary: summary) { _ in
                        // Handle user tap
                        showKudosList = false
                        // Navigate to user profile
                    }
                    .navigationTitle("Kudos")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showKudosList = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func workoutIcon(for type: String) -> String {
        switch type.lowercased() {
        case "running":
            "figure.run"
        case "cycling":
            "bicycle"
        case "swimming":
            "figure.pool.swim"
        case "walking":
            "figure.walk"
        case "hiking":
            "figure.hiking"
        case "yoga":
            "figure.yoga"
        case "strength training", "functional strength training", "traditional strength training":
            "dumbbell"
        default:
            "figure.mixed.cardio"
        }
    }
}

// MARK: - Stat Badge Component

private struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}
