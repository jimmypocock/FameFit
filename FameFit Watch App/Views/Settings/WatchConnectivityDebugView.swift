//
//  WatchConnectivityDebugView.swift
//  FameFit Watch App
//
//  Debug view for WatchConnectivity in TestFlight
//

import SwiftUI
import WatchConnectivity

struct WatchConnectivityDebugView: View {
    @ObservedObject private var debugger = WatchConnectivityDebugger.shared
    @State private var selectedMessage: WatchConnectivityDebugger.DebugMessage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                connectionCard
                syncStatusCard
                messagesCard
                actionsCard
            }
            .padding(.horizontal)
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            debugger.updateConnectionStatus()
        }
    }
    
    // MARK: - Cards
    
    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                MiniStatusRow(title: "Paired", isActive: debugger.connectionStatus.isPaired)
                MiniStatusRow(title: "Reachable", isActive: debugger.connectionStatus.isReachable)
                MiniStatusRow(title: "Pending", isActive: debugger.connectionStatus.hasContentPending)
            }
            
            Text(debugger.connectionStatus.activationState)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var syncStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync Status")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            if let lastSync = debugger.lastSyncDate {
                HStack {
                    Text("Last:")
                        .font(.caption2)
                    Spacer()
                    Text(lastSync, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            HStack {
                Text("Queue:")
                    .font(.caption2)
                Spacer()
                Text("\(debugger.pendingTransfers)")
                    .font(.caption2)
                    .foregroundColor(debugger.pendingTransfers > 0 ? .orange : .secondary)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var messagesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Messages")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(debugger.recentMessages.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if debugger.recentMessages.isEmpty {
                Text("No messages")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(debugger.recentMessages.suffix(5).reversed()) { message in
                        MiniMessageRow(message: message)
                            .onTapGesture {
                                selectedMessage = message
                            }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .sheet(item: $selectedMessage) { message in
            MessageDetailSheet(message: message)
        }
    }
    
    private var actionsCard: some View {
        VStack(spacing: 8) {
            Button(action: {
                debugger.sendTestMessage()
            }) {
                Label("Test", systemImage: "paperplane")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            
            HStack(spacing: 8) {
                Button(action: {
                    Task { await syncNow() }
                }) {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Button(action: {
                    debugger.clearMessages()
                }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .tint(.red)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Helper Methods
    
    private func syncNow() async {
        // Request sync from iPhone
        let message: [String: Any] = [
            "id": UUID().uuidString,
            "type": "syncRequest",
            "timestamp": Date()
        ]
        
        WCSession.default.transferUserInfo(message)
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
        
        debugger.updateConnectionStatus()
    }
}

// MARK: - Supporting Views

struct MiniStatusRow: View {
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption2)
            Spacer()
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
    }
}

struct MiniMessageRow: View {
    let message: WatchConnectivityDebugger.DebugMessage
    
    var body: some View {
        HStack(spacing: 4) {
            Text(message.direction.rawValue)
                .font(.system(size: 10))
                .foregroundColor(message.direction == .sent ? .blue : .green)
            
            Text(message.messageType)
                .font(.system(size: 10).bold())
                .lineLimit(1)
            
            Spacer()
            
            Text(message.deliveryMethod.rawValue)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct MessageDetailSheet: View {
    let message: WatchConnectivityDebugger.DebugMessage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: message.direction == .sent ? "arrow.up.circle" : "arrow.down.circle")
                            Text(message.direction == .sent ? "Sent" : "Received")
                        }
                        .font(.caption.bold())
                        
                        Text("Type: \(message.messageType)")
                            .font(.caption2)
                        Text("Via: \(message.deliveryMethod.rawValue)")
                            .font(.caption2)
                        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    
                    // Summary
                    Text("Summary")
                        .font(.caption.bold())
                    Text(message.summary)
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    
                    // Raw data (simplified for Watch)
                    Text("Data")
                        .font(.caption.bold())
                    Text(formatCompactMessage(message.fullMessage))
                        .font(.system(size: 10, design: .monospaced))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding()
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatCompactMessage(_ dict: [String: Any]) -> String {
        // Compact format for Watch screen
        dict.compactMap { key, value in
            if let date = value as? Date {
                return "\(key): \(date.formatted(date: .omitted, time: .shortened))"
            } else if let dict = value as? [String: Any] {
                return "\(key): [\(dict.count) items]"
            } else {
                return "\(key): \(String(describing: value).prefix(30))"
            }
        }.joined(separator: "\n")
    }
}