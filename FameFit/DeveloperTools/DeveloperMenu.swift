//
//  DeveloperMenu.swift
//  FameFit
//
//  Developer tools menu for testing and data setup
//  IMPORTANT: This file is only included in DEBUG builds
//

#if DEBUG
import SwiftUI

enum DeveloperSheetType: Identifiable {
    case personaPicker
    case profilePicker
    case navigationDebug
    
    var id: String {
        switch self {
        case .personaPicker: return "personaPicker"
        case .profilePicker: return "profilePicker"
        case .navigationDebug: return "navigationDebug"
        }
    }
}

struct DeveloperMenu: View {
    @State private var isLoading = false
    @State private var message = ""
    @State private var sheetType: DeveloperSheetType?
    @State private var selectedPersona: TestAccountPersona?
    @State private var existingAccounts: [TestAccountPersona] = []
    @Environment(\.dismiss) var dismiss
    @Environment(\.dependencyContainer) var dependencyContainer
    
    private let seeder = CloudKitSeeder()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Developer Tools")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)
                
                // Menu Options
                VStack(spacing: 16) {
                    // Setup Persona
                    Button(action: setupPersona) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.title3)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Setup Persona")
                                    .font(.headline)
                                Text("Update your account with test data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Create a Profile
                    Button(action: createProfile) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create a Profile")
                                    .font(.headline)
                                Text("Create a new test profile")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Debug CloudKit
                    Button(action: debugCloudKit) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.title3)
                                .frame(width: 30)
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Debug CloudKit")
                                    .font(.headline)
                                Text("Check CloudKit environment & data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Navigation Debug
                    Button(action: { sheetType = .navigationDebug }) {
                        HStack {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.title3)
                                .frame(width: 30)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Navigation Debug")
                                    .font(.headline)
                                Text("View navigation paths & test deep links")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Clear Cache
                    Button(action: clearCache) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.title3)
                                .frame(width: 30)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Clear Cache")
                                    .font(.headline)
                                Text("Clear all local cached data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Recalculate Stats
                    Button(action: recalculateStats) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title3)
                                .frame(width: 30)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recalculate Stats")
                                    .font(.headline)
                                Text("Sync workout count & XP from records")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Force Reset Stats
                    Button(action: forceResetStats) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .frame(width: 30)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Force Reset Stats")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                Text("Reset stats to 0 (bypass workout query)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Reset Account
                    Button(action: resetAccount) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3)
                                .frame(width: 30)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Account")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("Delete all data and restart")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Status/Loading
                if isLoading {
                    ProgressView()
                        .padding()
                }
                
                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Close button
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
        .sheet(item: $sheetType) { type in
            switch type {
            case .personaPicker:
                PersonaSelectionView(title: "Select Persona", 
                                   subtitle: "Choose test data to apply to your account",
                                   onSelect: { persona in
                                       sheetType = nil
                                       applyPersonaToCurrentAccount(persona)
                                   })
            case .profilePicker:
                PersonaSelectionView(title: "Create New Profile",
                                   subtitle: "Choose a persona for the new profile",
                                   existingAccounts: existingAccounts,
                                   onSelect: { persona in
                                       sheetType = nil
                                       createNewProfile(with: persona)
                                   })
            case .navigationDebug:
                NavigationDebugView()
            }
        }
        .task {
            await loadExistingAccounts()
        }
    }
    
    // MARK: - Actions
    
    private func loadExistingAccounts() async {
        let registry = UserDefaults.standard.dictionary(forKey: "TestAccountRegistry") ?? [:]
        existingAccounts = registry.compactMap { key, _ in
            TestAccountPersona(rawValue: key)
        }
    }
    
    private func setupPersona() {
        sheetType = .personaPicker
    }
    
    private func createProfile() {
        sheetType = .profilePicker
    }
    
    private func debugCloudKit() {
        Task {
            isLoading = true
            message = "Debugging CloudKit environment..."
            
            do {
                let container = dependencyContainer
                let cloudKitManager = container.cloudKitManager
                
                try await cloudKitManager.debugCloudKitEnvironment()
                
                message = "✅ Check console for CloudKit debug info"
            } catch {
                message = "❌ Debug failed: \(error.localizedDescription)"
            }
            
            isLoading = false
            
            // Clear message after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            message = ""
        }
    }
    
    private func recalculateStats() {
        Task {
            isLoading = true
            message = "Verifying and recalculating all counts..."
            
            do {
                // Use the new CountVerificationService
                let container = dependencyContainer
                let verificationService = container.countVerificationService
                
                // Force verification (marks as verified after completion)
                let result = try await verificationService.verifyAllCounts()
                
                if result.hadCorrections {
                    message = "✅ Counts corrected!\n\(result.summary)"
                } else {
                    message = "✅ All counts verified correctly!"
                }
                
                // Trigger profile refresh
                NotificationCenter.default.post(name: Notification.Name("RefreshUserProfile"), object: nil)
            } catch {
                message = "❌ Failed to verify counts: \(error.localizedDescription)"
            }
            
            isLoading = false
            
            // Clear message after delay
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds to read the summary
            message = ""
        }
    }
    
    private func forceResetStats() {
        Task {
            isLoading = true
            message = "Force resetting stats to zero..."
            
            do {
                let container = dependencyContainer
                let cloudKitManager = container.cloudKitManager
                
                try await cloudKitManager.forceResetStats()
                
                message = "✅ Stats force reset to zero!"
                
                // Trigger profile refresh
                NotificationCenter.default.post(name: Notification.Name("RefreshUserProfile"), object: nil)
            } catch {
                message = "❌ Failed to reset: \(error.localizedDescription)"
            }
            
            isLoading = false
            
            // Clear message after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            message = ""
        }
    }
    
    private func clearAllWorkouts() {
        Task {
            isLoading = true
            message = "Clearing all workouts..."
            
            do {
                let container = dependencyContainer
                let cloudKitManager = container.cloudKitManager
                
                try await cloudKitManager.clearAllWorkoutsAndResetStats()
                
                message = "✅ All workouts cleared and stats reset!"
                
                // Trigger profile refresh
                NotificationCenter.default.post(name: Notification.Name("RefreshUserProfile"), object: nil)
            } catch {
                message = "❌ Failed to clear workouts: \(error.localizedDescription)"
            }
            
            isLoading = false
            
            // Clear message after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            message = ""
        }
    }
    
    private func clearCache() {
        Task {
            isLoading = true
            message = "Clearing cache..."
            
            // Clear all UserDefaults cache keys
            let defaults = UserDefaults.standard
            let cacheKeys = [
                "cachedWorkouts",
                "cachedProfiles",
                "cachedFollowers",
                "cachedFollowing",
                "cachedActivities",
                "lastFetchTimestamps"
            ]
            
            for key in cacheKeys {
                defaults.removeObject(forKey: key)
            }
            
            // Clear any in-memory caches
            NotificationCenter.default.post(name: Notification.Name("ClearAllCaches"), object: nil)
            
            message = "✅ Cache cleared successfully"
            
            isLoading = false
        }
    }
    
    private func resetAccount() {
        Task {
            isLoading = true
            message = "Resetting account..."
            
            do {
                // Delete all CloudKit data for current user
                try await seeder.cleanupCurrentUserData()
                
                // Clear all UserDefaults
                if let bundleID = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                }
                
                // Post notification to reset app state
                await MainActor.run {
                    NotificationCenter.default.post(name: Notification.Name("ResetApplication"), object: nil)
                    
                    // Restart the app
                    // Note: In a real app, you might want to use a more graceful restart
                    // For now, we'll just dismiss and show a message
                    message = "✅ Account reset. Please restart the app."
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        exit(0) // Force quit the app
                    }
                }
            } catch {
                message = "❌ Error resetting account: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func applyPersonaToCurrentAccount(_ persona: TestAccountPersona) {
        Task {
            isLoading = true
            message = "Applying persona data..."
            
            do {
                // Update the current user's profile with persona data
                try await seeder.updateCurrentUserWithPersona(persona)
                
                // Setup social graph
                try await seeder.setupSocialGraph()
                
                // Seed workout history
                try await seeder.seedWorkoutHistory()
                
                // Seed activity feed
                try await seeder.seedActivityFeed()
                
                message = "✅ Persona applied successfully"
                
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch {
                message = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func createNewProfile(with persona: TestAccountPersona) {
        Task {
            isLoading = true
            message = "Creating new profile..."
            
            do {
                // Register a new account with the persona
                try await seeder.registerAccountAsPersona(persona)
                
                // Setup the profile
                try await seeder.setupProfileForPersona(persona)
                
                // Add some workout history
                try await seeder.seedWorkoutHistoryForPersona(persona)
                
                message = "✅ Profile created for \(persona.username)"
                
                // Update existing accounts list
                await loadExistingAccounts()
                
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    sheetType = nil
                }
            } catch {
                message = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
}

// MARK: - Persona Selection View

private struct PersonaSelectionView: View {
    let title: String
    let subtitle: String
    var existingAccounts: [TestAccountPersona] = []
    let onSelect: (TestAccountPersona) -> Void
    @Environment(\.dismiss) var dismiss
    
    var availablePersonas: [TestAccountPersona] {
        if existingAccounts.isEmpty {
            return TestAccountPersona.allCases
        } else {
            // Filter out personas that are already in use
            return TestAccountPersona.allCases.filter { persona in
                !existingAccounts.contains(persona)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical)
                
                if availablePersonas.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Available Personas")
                            .font(.headline)
                        
                        Text("All test personas are already in use")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(availablePersonas, id: \.self) { persona in
                        Button(action: {
                            onSelect(persona)
                            dismiss()
                        }) {
                            HStack(spacing: 16) {
                                // Avatar
                                Circle()
                                    .fill(Color(persona.accentColor))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Text(persona.initials)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(persona.username)
                                            .font(.headline)
                                        
                                        if persona.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Text(persona.bio)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                    
                                    HStack(spacing: 16) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                            Text("\(persona.totalXP.formatted()) XP")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "figure.run")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                            Text("\(persona.workoutCount) workouts")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
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

// MARK: - TestAccountPersona Extensions

extension TestAccountPersona {
    var initials: String {
        username.prefix(2).uppercased()
    }
    
    var accentColor: UIColor {
        switch self {
        case .athlete: return .systemBlue
        case .beginner: return .systemPink
        case .influencer: return .systemPurple
        case .coach: return .systemOrange
        case .casual: return .systemGreen
        }
    }
}

// MARK: - Shake Gesture Extension

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            action()
        }
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("DeviceDidShake")
}

// MARK: - Shake Detection

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}
#endif