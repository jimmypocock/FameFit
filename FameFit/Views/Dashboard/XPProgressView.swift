//
//  XPProgressView.swift
//  FameFit
//
//  Displays XP level progress and upcoming unlocks
//

import SwiftUI

struct XPProgressView: View {
    let currentXP: Int
    let level: Int
    let title: String
    let nextLevelXP: Int
    let nextUnlock: XPUnlock?

    init(currentXP: Int) {
        self.currentXP = currentXP
        let levelInfo = XPCalculator.getLevel(for: currentXP)
        level = levelInfo.level
        title = levelInfo.title
        nextLevelXP = levelInfo.nextLevelXP
        nextUnlock = XPCalculator.getNextUnlock(for: currentXP)
    }

    private var progressToNextLevel: Double {
        XPCalculator.calculateProgress(currentXP: currentXP, toNextLevel: nextLevelXP)
    }

    private var xpToNextLevel: Int {
        nextLevelXP == Int.max ? 0 : nextLevelXP - currentXP
    }

    var body: some View {
        VStack(spacing: 20) {
            levelHeader
            progressBar
            if let nextUnlock {
                nextUnlockView(nextUnlock)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
    }

    private var levelHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Level \(level)")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Influencer XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(currentXP.formattedWithSeparator()) XP")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }

            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                if xpToNextLevel > 0 {
                    Text("\(xpToNextLevel.formattedWithSeparator()) to next level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(height: 12)

                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: {
                        let width = geometry.size.width * progressToNextLevel
                        if width.isNaN || width.isInfinite {
                            FameFitLogger.warning("📊 XPProgressView: NaN/Infinite width detected! geometry.size.width=\(geometry.size.width), progressToNextLevel=\(progressToNextLevel)", category: FameFitLogger.ui)
                            return 0
                        }
                        return width
                    }(), height: 12)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progressToNextLevel)
            }
        }
        .frame(height: 12)
        .overlay(
            Text("\(Int(progressToNextLevel * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .background(Capsule().fill(Color.black.opacity(0.7)))
                .opacity(progressToNextLevel > 0.1 ? 1 : 0)
        )
    }

    private func nextUnlockView(_ unlock: XPUnlock) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconForCategory(unlock.category))
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.accentColor.opacity(0.1)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Next Unlock: \(unlock.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(unlock.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(unlock.xpRequired.formattedWithSeparator()) XP")
                    .font(.caption)
                    .fontWeight(.medium)

                Text("\((unlock.xpRequired - currentXP).formattedWithSeparator()) away")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private func iconForCategory(_ category: XPUnlock.UnlockCategory) -> String {
        switch category {
        case .badge:
            "rosette"
        case .feature:
            "sparkles"
        case .customization:
            "paintbrush.fill"
        case .achievement:
            "trophy.fill"
        }
    }
}

private extension Int {
    func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

struct XPProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            XPProgressView(currentXP: 0)
            XPProgressView(currentXP: 250)
            XPProgressView(currentXP: 1_234)
            XPProgressView(currentXP: 999_999)
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
