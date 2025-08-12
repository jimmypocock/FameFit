//
//  MockModeIndicator.swift
//  FameFit
//
//  Visual indicator when using mock data
//

#if DEBUG

import SwiftUI

struct MockModeIndicator: View {
    @State private var showingDebugMenu = false
    
    var body: some View {
        if ServiceResolver.isUsingMockData {
            Button(action: {
                showingDebugMenu = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.caption2)
                    Text("MOCK DATA")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(4)
            }
            .sheet(isPresented: $showingDebugMenu) {
                DebugMenuView()
            }
        }
    }
}

// View modifier for easy integration
struct MockModeIndicatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                MockModeIndicator()
                    .padding(.top, 8)
            }
    }
}

extension View {
    func mockModeIndicator() -> some View {
        #if DEBUG
        modifier(MockModeIndicatorModifier())
        #else
        self
        #endif
    }
}

#endif