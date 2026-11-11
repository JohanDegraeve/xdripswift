//
//  DirectWatchCollectionGesture.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 13/10/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Add triple tap alongside the glucose views' existing double-tap and chart gestures.
struct DirectWatchCollectionGesture: ViewModifier {
    @EnvironmentObject private var watchState: WatchStateModel
    @State private var feedbackSymbol: String?
    @State private var feedbackID = UUID()
    @State private var feedbackScale: CGFloat = 0.7
    @State private var feedbackOpacity: Double = 0

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 3).onEnded { toggleCollection() }
            )
            .overlay { feedbackOverlay }
    }

    private var feedbackOverlay: some View {
        GeometryReader { available in
            ZStack {
                Color.black.opacity(0.45)
                Image(systemName: feedbackSymbol ?? ConstantsDirectWatch.pauseSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(available.size.width, available.size.height) * 0.75,
                           height: min(available.size.width, available.size.height) * 0.75)
                    .foregroundStyle(.colorPrimary)
                    .background(Color.black.opacity(0.8), in: Circle())
                    .scaleEffect(feedbackScale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(feedbackOpacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(feedbackSymbol == nil)
        .accessibilityLabel(watchState.directWatchCollector.isPaused ? TextsDirectWatch.paused : TextsDirectWatch.resume)
        .task(id: feedbackID) { await pulseFeedback() }
    }

    private func pulseFeedback() async {
        guard feedbackSymbol != nil else { return }
        // Show a one-second pulse. A new action cancels the previous dismissal.
        do {
            withAnimation(.easeOut(duration: 0.3)) {
                feedbackScale = 1
                feedbackOpacity = 1
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeIn(duration: 0.5)) {
                feedbackOpacity = 0
                feedbackScale = 1.15
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            feedbackSymbol = nil
        } catch { }
    }

    private func toggleCollection() {
        let collector = watchState.directWatchCollector
        guard collector.isConfigured else { return }
        let paused = !collector.isPaused
        collector.setPaused(paused)
        guard collector.isPaused == paused else { return }
        feedbackSymbol = paused ? ConstantsDirectWatch.pauseSymbol : ConstantsDirectWatch.resumeSymbol
        feedbackID = UUID()
        feedbackScale = 0.7
        feedbackOpacity = 0
    }
}
