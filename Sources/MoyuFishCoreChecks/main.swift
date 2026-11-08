import Foundation
import Darwin
import MoyuFishCore

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    print("PASS: \(message)")
}

let rules = [ClassificationRule(target: .init(kind: .application, name: "Safari"), category: .focus)]
check(ActivityClassifier.classify(applicationName: " safari ", rules: rules) == .focus, "application classification ignores case and surrounding spaces")

let start = Date(timeIntervalSince1970: 1_700_000_000)
var leisureState = UsageState(
    setupComplete: true,
    settings: TrackingSettings(progressThresholdSeconds: 60, retentionPeriod: .thirtyDays),
    rules: [ClassificationRule(target: .init(kind: .application, name: "Chrome"), category: .leisure)]
)
leisureState.settings.progressThresholdSeconds = 60
var leisureEngine = TrackingEngine(state: leisureState)
let leisureSample = ActivitySample(applicationName: "Chrome")
_ = leisureEngine.update(sample: leisureSample, now: start)
_ = leisureEngine.update(sample: leisureSample, now: start.addingTimeInterval(1))
check(leisureEngine.state.progressSeconds == 1, "leisure time increments the progress without early celebration")
for second in 2...60 {
    _ = leisureEngine.update(sample: leisureSample, now: start.addingTimeInterval(TimeInterval(second)))
}
check(leisureEngine.state.progressSeconds == 0 && leisureEngine.state.celebrationPending, "progress threshold triggers one pending celebration and resets")
check(leisureEngine.state.dailySummary(for: start).leisureSeconds == 60, "leisure records are included in daily totals")

var ignoredState = UsageState(
    setupComplete: true,
    rules: [ClassificationRule(target: .init(kind: .application, name: "Private"), category: .ignored)]
)
var ignoredEngine = TrackingEngine(state: ignoredState)
let privateSample = ActivitySample(applicationName: "Private")
_ = ignoredEngine.update(sample: privateSample, now: start)
_ = ignoredEngine.update(sample: privateSample, now: start.addingTimeInterval(1))
check(ignoredEngine.state.records.isEmpty, "ignored activity does not create time records")

var manualState = UsageState(
    setupComplete: true,
    settings: TrackingSettings(idleThresholdSeconds: 300, recoveryMode: .manual),
    rules: [ClassificationRule(target: .init(kind: .application, name: "Editor"), category: .focus)]
)
var manualEngine = TrackingEngine(state: manualState)
let editor = ActivitySample(applicationName: "Editor")
_ = manualEngine.update(sample: editor, now: start)
let idle = ActivitySample(applicationName: "Editor", idleSeconds: 300)
check(manualEngine.update(sample: idle, now: start.addingTimeInterval(1)).status == .resumeRequired, "idle timeout enters manual recovery state")
check(manualEngine.update(sample: editor, now: start.addingTimeInterval(2)).status == .resumeRequired, "manual recovery remains paused on user activity")
manualEngine.resumeByUser(at: start.addingTimeInterval(2))
_ = manualEngine.update(sample: editor, now: start.addingTimeInterval(3))
_ = manualEngine.update(sample: editor, now: start.addingTimeInterval(4))
check(manualEngine.state.dailySummary(for: start).focusSeconds == 2, "manual resume starts a new focus interval after preserving pre-idle time")

var browserEngine = TrackingEngine(state: UsageState(
    setupComplete: true,
    rules: [ClassificationRule(target: .init(kind: .application, name: "Chrome"), category: .leisure)]
))
let browser = ActivitySample(applicationName: "Chrome")
_ = browserEngine.update(sample: browser, now: start)
_ = browserEngine.update(sample: browser, now: start.addingTimeInterval(1))
check(browserEngine.state.dailySummary(for: start).leisureSeconds == 1, "browser is tracked as an ordinary application")

let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
defer { try? FileManager.default.removeItem(at: temp) }
let repository = UsageRepository(fileURL: temp.appendingPathComponent("usage.json"))
var saved = manualEngine.state
saved.settings.notificationsEnabled = true
saved.settings.retentionPeriod = .thirtyDays
saved.records.append(ActivityRecord(day: start.addingTimeInterval(-31 * 86_400), target: .init(kind: .application, name: "Old"), category: .focus, durationSeconds: 5))
let purged = try repository.purgeExpired(in: saved, now: start)
check(purged.records.allSatisfy { $0.target.name != "Old" }, "retention removes records older than selected window")
let cleared = try repository.clearHistory(from: purged)
check(cleared.records.isEmpty && cleared.rules == purged.rules && cleared.settings == purged.settings, "clear history keeps settings and classification rules")
let reloaded = try repository.load()
check(reloaded == cleared, "saved state reloads from local repository")

print("All core behavior checks passed.")
