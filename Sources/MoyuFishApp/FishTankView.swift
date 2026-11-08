import SwiftUI
import MoyuFishCore

struct FishTankView: View {
    @ObservedObject var model: MoyuFishModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var phase = 0.0
    @State private var phaseAnchor = Date()
    @State private var celebrationStart: Date?
    @State private var celebrationTask: Task<Void, Never>?

    private var animationPaused: Bool {
        !isVisible || reduceMotion || (model.fishSpeed == .stopped && celebrationStart == nil)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: animationPaused)) { context in
            FishTankScene(
                phase: reduceMotion ? 0 : currentPhase(at: context.date),
                waterTime: reduceMotion || model.fishSpeed == .stopped ? 0 : context.date.timeIntervalSince(phaseAnchor),
                resting: model.fishSpeed == .stopped,
                angry: model.currentActivity.category == .leisure,
                reduceMotion: reduceMotion,
                celebrationElapsed: celebrationStart.map { context.date.timeIntervalSince($0) }
            )
        }
        .frame(height: 172)
        .overlay(alignment: .top) {
            if celebrationStart != nil {
                Text("摸鱼时间到，伸个懒腰吧")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.12, green: 0.33, blue: 0.37))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white, in: Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("鱼缸里的小鱼：\(model.status.title)，\(model.currentActivity.category.title)")
        .onAppear {
            phaseAnchor = Date()
            isVisible = true
            if model.state.celebrationPending { startCelebration() }
        }
        .onDisappear {
            phase = currentPhase(at: Date())
            isVisible = false
            celebrationTask?.cancel()
            celebrationTask = nil
            celebrationStart = nil
        }
        .onChange(of: model.fishSpeed) { oldSpeed, _ in
            // Preserve position when switching between swimming and resting.
            if isVisible && !reduceMotion {
                phase += Date().timeIntervalSince(phaseAnchor) * oldSpeed.cyclesPerSecond * 1.8
            }
            phaseAnchor = Date()
        }
        .onChange(of: reduceMotion) { _, _ in
            phase = 0
            phaseAnchor = Date()
        }
        .onReceive(model.$celebrationToken.dropFirst()) { _ in
            if isVisible { startCelebration() }
        }
    }

    private func currentPhase(at date: Date) -> Double {
        phase + max(0, date.timeIntervalSince(phaseAnchor)) * model.fishSpeed.cyclesPerSecond * 1.8
    }

    private func startCelebration() {
        celebrationTask?.cancel()
        celebrationStart = Date()
        celebrationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_800))
            guard !Task.isCancelled else { return }
            celebrationStart = nil
            model.consumeCelebration()
        }
    }
}
