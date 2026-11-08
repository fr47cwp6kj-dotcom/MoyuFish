import AppKit
import Combine
import Foundation
import MoyuFishCore
import UserNotifications

@MainActor
final class MoyuFishModel: ObservableObject {
    @Published private(set) var state: UsageState
    @Published private(set) var status: TrackingStatus
    @Published private(set) var currentActivity: CurrentActivity
    @Published private(set) var celebrationToken = 0
    @Published private(set) var persistenceError: String?

    private let repository: UsageRepository
    private let systemMonitor = SystemActivityMonitor()
    private var engine: TrackingEngine
    private var lastSavedAt = Date.distantPast
    private var timer: Timer?
    private var lastRetentionSweep = Date.distantPast
    private var terminationObserver: NSObjectProtocol?

    init() {
        let repository = (try? UsageRepository.applicationDefault()) ?? UsageRepository(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("MoyuFish/usage.json")
        )
        self.repository = repository
        let loaded = (try? repository.load()) ?? UsageState()
        self.state = loaded
        self.engine = TrackingEngine(state: loaded)
        self.status = loaded.setupComplete ? .recording : .setupRequired
        self.currentActivity = CurrentActivity()

        if let retained = try? repository.purgeExpired(in: loaded) {
            self.state = retained
            self.engine.replaceState(retained)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.persist()
            }
        }
        tick()
    }

    var dailySummary: DailySummary { state.dailySummary() }
    var fishSpeed: FishSpeed {
        switch status {
        case .setupRequired, .userPaused, .idle, .locked, .resumeRequired: .stopped
        case .recording:
            switch currentActivity.category {
            case .leisure: .fast
            case .focus: .slow
            case .ignored, .unclassified: .normal
            }
        }
    }

    func completeSetup(retention: RetentionPeriod, idleMinutes: Int, recoveryMode: RecoveryMode, progressMinutes: Int) {
        var updated = state
        updated.setupComplete = true
        updated.settings.retentionPeriod = retention
        updated.settings.idleThresholdSeconds = max(1, idleMinutes) * 60
        updated.settings.recoveryMode = recoveryMode
        updated.settings.progressThresholdSeconds = max(1, progressMinutes) * 60
        state = updated
        engine.replaceState(updated)
        persist()
        tick()
    }

    func pauseOrResume() {
        if status == .recording {
            engine.pauseByUser()
        } else if status == .userPaused || status == .resumeRequired || status == .idle || status == .locked {
            guard !systemMonitor.isLocked, !systemMonitor.isSleeping else { return }
            engine.resumeByUser()
        }
        syncEngineState()
        persist()
    }

    func updateSettings(_ settings: TrackingSettings) {
        let shouldAskForNotificationPermission = !state.settings.notificationsEnabled && settings.notificationsEnabled
        var updated = state
        updated.settings = settings
        updated.settings.idleThresholdSeconds = max(60, settings.idleThresholdSeconds)
        updated.settings.progressThresholdSeconds = max(60, settings.progressThresholdSeconds)
        state = updated
        engine.replaceState(updated)
        if engine.state.celebrationPending {
            celebrationToken += 1
        }
        _ = try? repository.purgeExpired(in: updated)
        persist()
        if shouldAskForNotificationPermission {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        tick()
    }

    func addRule(target: ActivityTarget, category: ActivityCategory) {
        guard target.kind == .application, category != .unclassified, !target.name.isEmpty else { return }
        var updated = state
        updated.rules.removeAll { $0.target == target }
        updated.rules.append(ClassificationRule(target: target, category: category))
        state = updated
        engine.replaceState(updated)
        persist()
        tick()
    }

    func removeRule(_ rule: ClassificationRule) {
        var updated = state
        updated.rules.removeAll { $0.id == rule.id }
        state = updated
        engine.replaceState(updated)
        persist()
        tick()
    }

    func clearHistory() {
        do {
            state = try repository.clearHistory(from: state)
            engine.replaceState(state)
            persistenceError = nil
        } catch {
            persistenceError = "无法清除本地记录：\(error.localizedDescription)"
        }
    }

    func consumeCelebration() {
        engine.consumePendingCelebration()
        syncEngineState()
        persist()
    }

    func save() { persist() }

    private func tick() {
        let sample = systemMonitor.sample()
        let update = engine.update(sample: sample)
        if update.celebrationTriggered {
            celebrationToken += 1
            if state.settings.notificationsEnabled {
                sendMilestoneNotification()
            }
        }
        syncEngineState()
        if Date().timeIntervalSince(lastRetentionSweep) >= 86_400 {
            if let purged = try? repository.purgeExpired(in: state) {
                lastRetentionSweep = Date()
                if purged.records.count != state.records.count {
                    state = purged
                    engine.replaceState(purged)
                }
            }
        }
        if Date().timeIntervalSince(lastSavedAt) >= 5 { persist() }
    }

    private func syncEngineState() {
        state = engine.state
        status = engine.status
        currentActivity = engine.currentActivity
    }

    private func persist() {
        do {
            try repository.save(engine.state)
            lastSavedAt = Date()
            persistenceError = nil
        } catch {
            persistenceError = "无法保存本地记录：\(error.localizedDescription)"
        }
    }

    private func sendMilestoneNotification() {
        let content = UNMutableNotificationContent()
        content.title = "摸鱼鱼"
        content.body = "这一轮摸鱼时间到啦，起来活动一下吧。"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
    }
}

enum FishSpeed: Equatable {
    case stopped
    case slow
    case normal
    case fast

    var cyclesPerSecond: Double {
        switch self {
        case .stopped: 0
        case .slow: 0.25
        case .normal: 0.45
        case .fast: 0.9
        }
    }
}
