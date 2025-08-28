//
//  WatchConnectivityDebugView.swift
//  FameFit
//
//  Debug view for WatchConnectivity in TestFlight
//

import SwiftUI
import WatchConnectivity

struct WatchConnectivityDebugView: View {
    @ObservedObject private var debugger = WatchConnectivityDebugger.shared
    @State private var showingMessageDetail: WatchConnectivityDebugger.DebugMessage?
    
    var body: some View {
        List {
            connectionSection
            statusSection
            recentMessagesSection
            actionsSection
        }
        .navigationTitle("Watch Debug")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            debugger.updateConnectionStatus()
        }
        .refreshable {
            debugger.updateConnectionStatus()
        }
        .sheet(item: $showingMessageDetail) { message in
            MessageDetailView(message: message)
        }
    }
    
    // MARK: - Sections
    
    private var connectionSection: some View {
        Section("Connection Status") {
            StatusRow(title: "Paired", isActive: debugger.connectionStatus.isPaired)
            StatusRow(title: "Watch App Installed", isActive: debugger.connectionStatus.isWatchAppInstalled)
            StatusRow(title: "Reachable", isActive: debugger.connectionStatus.isReachable)
            StatusRow(title: "Has Pending Content", isActive: debugger.connectionStatus.hasContentPending)
            
            HStack {
                Text("Activation State")
                Spacer()
                Text(debugger.connectionStatus.activationState)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statusSection: some View {
        Section("Sync Status") {
            if let lastSync = debugger.lastSyncDate {
                HStack {
                    Text("Last Sync")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text("Pending Transfers")
                Spacer()
                Text("\(debugger.pendingTransfers)")
                    .foregroundColor(debugger.pendingTransfers > 0 ? .orange : .secondary)
            }
            
            HStack {
                Text("Message Queue")
                Spacer()
                Text("\(debugger.recentMessages.count) / 20")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var recentMessagesSection: some View {
        Section("Recent Messages") {
            if debugger.recentMessages.isEmpty {
                Text("No messages yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(debugger.recentMessages.reversed()) { message in
                    MessageRow(message: message)
                        .onTapGesture {
                            showingMessageDetail = message
                        }
                }
            }
        }
    }
    
    private var actionsSection: some View {
        Section("Actions") {
            Button(action: {
                debugger.sendTestMessage()
            }) {
                Label("Send Test Message", systemImage: "paperplane")
            }
            
            Button(action: {
                Task {
                    await forceSync()
                }
            }) {
                Label("Force Sync", systemImage: "arrow.triangle.2.circlepath")
            }
            
            Button(action: {
                debugger.clearMessages()
            }) {
                Label("Clear Message Log", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Helper Methods
    
    private func forceSync() async {
        // Request fresh data from Watch
        let message: [String: Any] = [
            "id": UUID().uuidString,
            "type": "syncRequest",
            "timestamp": Date()
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: { _ in
                debugger.updateConnectionStatus()
            }, errorHandler: nil)
        }
        
        // Also try to fetch any pending transfers
        debugger.updateConnectionStatus()
    }
}

// MARK: - Supporting Views

struct StatusRow: View {
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isActive ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isActive ? .green : .gray)
        }
    }
}

struct MessageRow: View {
    let message: WatchConnectivityDebugger.DebugMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.direction.rawValue)
                    .font(.caption)
                    .foregroundColor(message.direction == .sent ? .blue : .green)
                
                Text(message.messageType)
                    .font(.caption.bold())
                
                Spacer()
                
                Text(message.formattedTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(message.deliveryMethod.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 2)
    }
}

struct MessageDetailView: View {
    let message: WatchConnectivityDebugger.DebugMessage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header info
                    VStack(alignment: .leading, spacing: 8) {
                        Label(message.direction == .sent ? "Sent" : "Received", 
                              systemImage: message.direction == .sent ? "arrow.up.circle" : "arrow.down.circle")
                            .font(.headline)
                        
                        Text("Type: \(message.messageType)")
                        Text("Method: \(message.deliveryMethod.rawValue)")
                        Text("Time: \(message.timestamp.formatted())")
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Message content
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message Content")
                            .font(.headline)
                        
                        Text(formatMessageContent(message.fullMessage))
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Message Detail")
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
    
    private func formatMessageContent(_ dict: [String: Any]) -> String {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: dict)
    }
}