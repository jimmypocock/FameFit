//
//  AccountSetupView.swift
//  FameFit Watch App
//
//  View shown when no FameFit account is detected
//

import SwiftUI

struct AccountSetupView: View {
    @ObservedObject var accountService: AccountVerificationService
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                    .padding(.top)
                
                // Title
                Text("Account Setup")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                // Message based on status
                if !accountService.accountStatus.displayMessage.isEmpty {
                    Text(accountService.accountStatus.displayMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Action buttons
                VStack(spacing: 8) {
                    // Primary: Set up on iPhone
                    Button(action: {
                        // Can't actually open iPhone app from Watch
                        // Just show instruction
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "iphone")
                                .font(.title3)
                            Text("Set Up on iPhone")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // Secondary: Continue without account
                    Button(action: {
                        accountService.continueWithoutAccount()
                    }) {
                        Text("Continue Without")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    
                    // Refresh button if offline/error
                    if case .offline = accountService.accountStatus {
                        Button(action: {
                            Task {
                                isRefreshing = true
                                await accountService.checkAccountStatus(forceRefresh: true)
                                isRefreshing = false
                            }
                        }) {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.borderless)
                        .disabled(isRefreshing)
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom)
                
                // Info text
                VStack(spacing: 4) {
                    Text("Without an account:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    
                    Text("• Workouts save to Health only")
                        .font(.caption2)
                    Text("• No XP or achievements")
                        .font(.caption2)
                    Text("• No social features")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
        }
        .navigationTitle("FameFit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AccountSetupView(accountService: AccountVerificationService())
    }
}