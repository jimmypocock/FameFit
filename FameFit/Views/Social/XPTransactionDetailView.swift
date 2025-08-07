//
//  XPTransactionDetailView.swift
//  FameFit
//
//  Displays XP calculation breakdown for a workout
//

import SwiftUI

struct XPTransactionDetailView: View {
    let transaction: XPTransaction
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // XP Summary
                    VStack(spacing: 16) {
                        HStack(alignment: .bottom, spacing: 8) {
                            Text("\(transaction.finalXP)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                            
                            Text("XP")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)
                        }
                        
                        HStack(spacing: 16) {
                            Label("\(transaction.baseXP) base", systemImage: "star")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Label("\(transaction.multiplierText) multiplier", systemImage: "multiply")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Workout Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Workout Details")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            XPDetailRow(label: "Type", value: transaction.factors.workoutType)
                            XPDetailRow(label: "Duration", value: formatDuration(transaction.factors.duration))
                            XPDetailRow(label: "Day", value: transaction.factors.dayOfWeek)
                            XPDetailRow(label: "Time", value: transaction.factors.timeOfDay)
                            
                            if transaction.factors.consistencyStreak > 0 {
                                XPDetailRow(
                                    label: "Streak",
                                    value: "\(transaction.factors.consistencyStreak) days",
                                    valueColor: .orange
                                )
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // Bonuses
                    if !transaction.factors.bonuses.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Bonuses Applied")
                                .font(.headline)
                            
                            VStack(spacing: 12) {
                                ForEach(transaction.factors.bonuses, id: \.type) { bonus in
                                    HStack {
                                        Image(systemName: bonus.iconName)
                                            .foregroundColor(Color(bonus.color))
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(bonus.description)
                                                .font(.subheadline)
                                            
                                            Text("+\(Int((bonus.multiplier - 1) * 100))% bonus")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(String(format: "%.1f", bonus.multiplier))x")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Milestones
                    if !transaction.factors.milestones.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Milestones Achieved")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(transaction.factors.milestones, id: \.self) { milestone in
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        
                                        Text(milestone)
                                            .font(.subheadline)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Timestamp
                    Text(transaction.formattedTimestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("XP Breakdown")
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

private struct XPDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct XPTransactionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        XPTransactionDetailView(
            transaction: XPTransaction(
                userID: "test-user",
                workoutRecordID: "test-workout",
                baseXP: 30,
                finalXP: 54,
                factors: XPCalculationFactors(
                    workoutType: "Running",
                    duration: 1800,
                    dayOfWeek: "Saturday",
                    timeOfDay: "Morning",
                    consistencyStreak: 5,
                    milestones: ["50 workouts completed!"],
                    bonuses: [
                        XPBonus(type: .weekendWarrior, multiplier: 1.15, description: "Weekend warrior bonus"),
                        XPBonus(type: .consistencyStreak, multiplier: 1.25, description: "5 day streak bonus"),
                        XPBonus(type: .milestone, multiplier: 2.0, description: "50 workout milestone")
                    ]
                )
            )
        )
    }
}
#endif