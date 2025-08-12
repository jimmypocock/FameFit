//
//  NowPlayingView.swift
//  FameFit Watch App
//
//  Now Playing view for workout session
//

import SwiftUI
import WatchKit

struct NowPlayingView: View {
    var body: some View {
        VStack {
            Image(systemName: "music.note")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Now Playing")
                .font(.headline)
            
            Text("Control music playback")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}