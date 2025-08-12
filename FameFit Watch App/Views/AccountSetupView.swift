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
                
                // Single continue button
                Button(action: {
                    accountService.continueWithoutAccount()
                }) {
                    Text("Continue to Workouts")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.top, 8)
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