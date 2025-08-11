//
//  FameFitApp.swift
//  FameFit Watch App
//
//  Created by Jimmy Pocock on 6/27/25.
//

#if os(watchOS)
import SwiftUI

@main
struct FameFitApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    @StateObject private var accountService = AccountVerificationService()
    @State private var hasCheckedAccount = false

    init() {
        // Initialize WatchConnectivity early to be ready for messages
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Group {
                    // Show appropriate view based on account status
                    switch accountService.accountStatus {
                    case .checking:
                        // Loading state
                        VStack {
                            ProgressView()
                            Text("Checking account...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    case .notFound, .error:
                        // Show setup prompt if needed, otherwise show workout view
                        if accountService.shouldPromptForSetup() {
                            AccountSetupView(accountService: accountService)
                        } else {
                            WatchStartView()
                                .overlay(alignment: .top) {
                                    NoAccountBanner()
                                }
                        }
                    case .verified, .offline:
                        // Has account (verified or cached), show normal view
                        WatchStartView()
                            .overlay(alignment: .top) {
                                if case .offline = accountService.accountStatus {
                                    OfflineBanner()
                                }
                            }
                    }
                }
                .sheet(isPresented: $workoutManager.showingSummaryView) {
                    SummaryView()
                }
                .environmentObject(workoutManager)
                .environmentObject(accountService)
            }
            .task {
                // Check account status on launch
                if !hasCheckedAccount {
                    hasCheckedAccount = true
                    await accountService.checkAccountStatus()
                }
            }
        }
    }
}

// MARK: - Banner Views

struct NoAccountBanner: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(.orange)
            Text("No Account")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
        .padding(.top, 4)
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(.caption2)
                .foregroundColor(.yellow)
            Text("Offline")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
        .padding(.top, 4)
    }
}
#endif
