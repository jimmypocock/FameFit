//
//  DeveloperMenu.swift
//  FameFit
//
//  Developer tools menu for testing and data setup
//  IMPORTANT: This file is only included in DEBUG builds
//

#if DEBUG
import SwiftUI

struct DeveloperMenu: View {
    @State private var isLoading = false
    @State private var message = ""
    @State private var showPersonaPicker = false
    @State private var selectedPersona: TestAccountPersona?
    @State private var currentUserID: String?
    @State private var currentPersona: TestAccountPersona?
    @Environment(\.dismiss) var dismiss
    
    private let seeder = CloudKitSeeder()
    
    var body: some View {
        menuContent
            .task {
                await loadCurrentUser()
            }
    }
    
    @ViewBuilder
    private var menuContent: some View {
        VStack(spacing: 20) {
            Text("🛠 Developer Menu")
                .font(.title2)
                .fontWeight(.bold)
            
            if let currentUserID {
                VStack(spacing: 8) {
                    Text("Current User")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(currentUserID)
                        .font(.caption2)
                        .monospaced()
                    
                    if let currentPersona {
                        Label(currentPersona.displayName, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            VStack(spacing: 12) {
                // Account Setup
                Group {
                    Button(action: registerAccount) {
                        Label("Register This Account", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    if currentPersona != nil {
                        Button(action: setupProfile) {
                            Label("Setup Profile", systemImage: "person.text.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: setupSocialGraph) {
                            Label("Setup Social Graph", systemImage: "person.2")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: seedWorkouts) {
                            Label("Seed Workout History", systemImage: "figure.run")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: seedActivityFeed) {
                            Label("Seed Activity Feed", systemImage: "newspaper")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                
                // Quick Actions
                Group {
                    Button(action: setupEverything) {
                        Label("Setup Everything", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button(action: cleanupData) {
                        Label("Clean All Data", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                Divider()
                
                Button(action: showInstructions) {
                    Label("Setup Instructions", systemImage: "questionmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            if isLoading {
                ProgressView()
                    .padding()
            }
            
            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
        .sheet(isPresented: $showPersonaPicker) {
            PersonaPicker(selectedPersona: $selectedPersona)
        }
        .onChange(of: selectedPersona) { oldValue, newValue in
            if let persona = newValue {
                currentPersona = persona
                selectedPersona = nil
                // Also reload from UserDefaults to ensure it's saved
                reloadCurrentPersona()
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentUser() async {
        do {
            currentUserID = try await seeder.getCurrentUserID()
            
            // Check if this user has a persona
            let registry = UserDefaults.standard.dictionary(forKey: "TestAccountRegistry") ?? [:]
            for (personaRaw, storedID) in registry {
                if storedID as? String == currentUserID,
                   let persona = TestAccountPersona(rawValue: personaRaw) {
                    currentPersona = persona
                    break
                }
            }
        } catch {
            message = "Error loading user: \(error.localizedDescription)"
        }
    }
    
    private func reloadCurrentPersona() {
        guard let currentUserID = currentUserID else { return }
        
        let registry = UserDefaults.standard.dictionary(forKey: "TestAccountRegistry") ?? [:]
        for (personaRaw, storedID) in registry {
            if storedID as? String == currentUserID,
               let persona = TestAccountPersona(rawValue: personaRaw) {
                currentPersona = persona
                break
            }
        }
    }
    
    private func registerAccount() {
        showPersonaPicker = true
    }
    
    private func setupProfile() {
        Task {
            isLoading = true
            message = ""
            
            do {
                try await seeder.setupCurrentUserProfile()
                message = "✅ Profile created successfully"
            } catch {
                message = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func setupSocialGraph() {
        Task {
            isLoading = true
            message = ""
            
            do {
                try await seeder.setupSocialGraph()
                message = "✅ Social relationships created"
            } catch {
                message = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func seedWorkouts() {
        Task {
            isLoading = true
            message = ""
            
            do {
                try await seeder.seedWorkoutHistory()
                message = "✅ Workout history created"
            } catch {
                message = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func seedActivityFeed() {
        Task {
            isLoading = true
            message = ""
            
            do {
                try await seeder.seedActivityFeed()
                message = "✅ Activity feed populated"
            } catch {
                message = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func setupEverything() {
        Task {
            isLoading = true
            message = "Setting up everything..."
            
            do {
                if currentPersona == nil {
                    message = "❌ Please register this account first"
                    isLoading = false
                    return
                }
                
                try await seeder.setupCurrentUserProfile()
                message = "Profile created..."
                
                try await seeder.setupSocialGraph()
                message = "Social graph created..."
                
                try await seeder.seedWorkoutHistory()
                message = "Workout history created..."
                
                try await seeder.seedActivityFeed()
                message = "✅ Everything set up successfully!"
            } catch {
                message = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func cleanupData() {
        Task {
            isLoading = true
            message = ""
            
            do {
                try await seeder.cleanupCurrentUserData()
                message = "✅ All data cleaned"
            } catch {
                message = "❌ Error: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func showInstructions() {
        message = TestAccountSetupGuide.instructions
    }
}

// MARK: - Persona Picker

private struct PersonaPicker: View {
    @Binding var selectedPersona: TestAccountPersona?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(TestAccountPersona.allCases, id: \.self) { persona in
                Button(action: {
                    selectPersona(persona)
                }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(persona.displayName)
                            .font(.headline)
                        Text("@\(persona.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(persona.bio)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            Label("\(persona.totalXP.formatted()) XP", systemImage: "star.fill")
                            Label("\(persona.workoutCount) workouts", systemImage: "figure.run")
                            if persona.isVerified {
                                Label("Verified", systemImage: "checkmark.seal.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Select Persona")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
    
    private func selectPersona(_ persona: TestAccountPersona) {
        Task {
            do {
                let seeder = CloudKitSeeder()
                try await seeder.registerCurrentAccount(as: persona)
                selectedPersona = persona
                dismiss()
            } catch {
                print("Error registering persona: \(error)")
            }
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