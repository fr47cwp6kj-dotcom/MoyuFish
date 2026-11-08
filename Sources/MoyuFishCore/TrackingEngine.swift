import Foundation

public struct TrackingEngine {
    public private(set) var state: UsageState
    public private(set) var status: TrackingStatus
    public private(set) var currentActivity: CurrentActivity

    private var lastTick: Date?
    private var previousWasSystemPaused = false
    private var userPaused = false
    private var previousContext: (target: ActivityTarget, category: ActivityCategory)?
    private var pendingCelebrationThisUpdate = false

    public init(state: UsageState) {
        self.state = state
        self.status = state.setupComplete ? .recording : .setupRequired
        self.currentActivity = CurrentActivity()
    }

    @discardableResult
    public mutating func update(sample: ActivitySample, now: Date = Date()) -> EngineUpdate {
        pendingCelebrationThisUpdate = false
        creditPreviousSample(until: now)
        lastTick = now

        guard state.setupComplete else {
            status = .setupRequired
            previousContext = nil
            currentActivity = CurrentActivity()
            return output()
        }

        let idle = sample.idleSeconds >= TimeInterval(state.settings.idleThresholdSeconds)
        let systemPaused = sample.isLocked || sample.isSleeping || idle

        if userPaused {
            status = .userPaused
            previousContext = nil
            currentActivity = resolveCurrentActivity(sample)
            return output()
        }

        if systemPaused {
            previousWasSystemPaused = true
            previousContext = nil
            if sample.isLocked || sample.isSleeping {
                status = .locked
            } else if state.settings.recoveryMode == .manual {
                status = .resumeRequired
            } else {
                status = .idle
            }
            currentActivity = resolveCurrentActivity(sample)
            return output()
        }

        if previousWasSystemPaused {
            previousWasSystemPaused = false
            if state.settings.recoveryMode == .manual {
                status = .resumeRequired
                previousContext = nil
                currentActivity = resolveCurrentActivity(sample)
                return output()
            }
        } else if status == .resumeRequired, state.settings.recoveryMode == .manual {
            previousContext = nil
            currentActivity = resolveCurrentActivity(sample)
            return output()
        }

        status = .recording
        currentActivity = resolveCurrentActivity(sample)
        if sample.isMoyuFish {
            currentActivity = CurrentActivity()
            previousContext = nil
            return output()
        }
        if currentActivity.category != .ignored, let target = currentActivity.target {
            previousContext = (target, currentActivity.category)
        } else {
            previousContext = nil
        }
        return output()
    }

    public mutating func pauseByUser(at date: Date = Date()) {
        userPaused = true
        lastTick = date
        previousContext = nil
        status = .userPaused
    }

    public mutating func resumeByUser(at date: Date = Date()) {
        userPaused = false
        previousWasSystemPaused = false
        lastTick = date
        previousContext = nil
        status = state.setupComplete ? .recording : .setupRequired
    }

    public mutating func replaceState(_ updated: UsageState, at date: Date = Date()) {
        state = updated
        lastTick = date
        previousContext = nil
        if !state.setupComplete {
            status = .setupRequired
            return
        }
        if state.progressSeconds >= max(60, state.settings.progressThresholdSeconds) {
            state.progressSeconds = 0
            state.celebrationPending = true
            pendingCelebrationThisUpdate = true
        }
    }

    public mutating func consumePendingCelebration() {
        state.celebrationPending = false
    }

    private mutating func creditPreviousSample(until now: Date) {
        guard status == .recording, let previousContext, let lastTick else { return }
        let elapsed = now.timeIntervalSince(lastTick)
        guard elapsed > 0 else { return }
        let seconds = min(2, Int(elapsed.rounded(.down)))
        guard seconds > 0 else { return }

        let day = Calendar.current.startOfDay(for: lastTick)
        if let index = state.records.firstIndex(where: {
            Calendar.current.isDate($0.day, inSameDayAs: day) &&
            $0.target == previousContext.target &&
            $0.category == previousContext.category
        }) {
            state.records[index].durationSeconds += seconds
        } else {
            state.records.append(ActivityRecord(
                day: day,
                target: previousContext.target,
                category: previousContext.category,
                durationSeconds: seconds
            ))
        }

        if previousContext.category == .leisure {
            state.progressSeconds += seconds
            if state.progressSeconds >= max(60, state.settings.progressThresholdSeconds) {
                state.progressSeconds = 0
                state.celebrationPending = true
                pendingCelebrationThisUpdate = true
            }
        }
    }

    private func resolveCurrentActivity(_ sample: ActivitySample) -> CurrentActivity {
        CurrentActivity(
            target: ActivityTarget(kind: .application, name: sample.applicationName),
            category: ActivityClassifier.classify(applicationName: sample.applicationName, rules: state.rules)
        )
    }

    private func output() -> EngineUpdate {
        EngineUpdate(status: status, currentActivity: currentActivity, celebrationTriggered: pendingCelebrationThisUpdate)
    }
}
