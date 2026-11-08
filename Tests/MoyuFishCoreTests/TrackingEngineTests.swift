import Foundation
import XCTest
@testable import MoyuFishCore

final class TrackingEngineTests: XCTestCase {
    func testBrowserApplicationsUseOnlyApplicationRules() {
        let rules = [
            ClassificationRule(target: .init(kind: .domain, name: "Safari"), category: .ignored),
            ClassificationRule(target: .init(kind: .application, name: "Safari"), category: .focus),
            ClassificationRule(target: .init(kind: .application, name: "Google Chrome"), category: .leisure)
        ]
        var engine = TrackingEngine(state: UsageState(setupComplete: true, rules: rules))
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for (second, app) in ["Safari", "Safari", "Google Chrome", "Google Chrome", "Editor", "Editor"].enumerated() {
            engine.update(sample: ActivitySample(applicationName: app), now: start.addingTimeInterval(Double(second)))
        }
        let summary = engine.state.dailySummary(for: start)
        XCTAssertEqual(summary.totalSeconds, 5)
        XCTAssertEqual(summary.focusSeconds, 2)
        XCTAssertEqual(summary.leisureSeconds, 2)
        XCTAssertEqual(summary.unclassifiedSeconds, 1)
        XCTAssertTrue(engine.state.records.allSatisfy { $0.target.kind == .application })
        XCTAssertEqual(ActivityClassifier.classify(applicationName: " safari ", rules: rules), .focus)
    }

    func testLegacyWebsiteDataRoundTripsButDoesNotAffectAppStatistics() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var state = makeState(category: .focus)
        state.settings.progressThresholdSeconds = 3600
        state.settings.retentionPeriod = .forever
        state.rules.append(ClassificationRule(target: .init(kind: .domain, name: "example.com"), category: .leisure))
        state.records = [
            ActivityRecord(day: start, target: .init(kind: .domain, name: "example.com"), category: .leisure, durationSeconds: 99),
            ActivityRecord(day: start, target: .init(kind: .application, name: "Editor"), category: .focus, durationSeconds: 12)
        ]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = UsageRepository(fileURL: directory.appendingPathComponent("usage.json"))
        try repository.save(state)
        let loaded = try repository.load()
        XCTAssertEqual(loaded, state)
        var engine = TrackingEngine(state: loaded)
        engine.update(sample: ActivitySample(applicationName: "Safari"), now: start)
        engine.update(sample: ActivitySample(applicationName: "Safari"), now: start.addingTimeInterval(1))
        XCTAssertEqual(engine.currentActivity.category, .unclassified)
        XCTAssertEqual(engine.state.records.first, state.records.first)
        XCTAssertEqual(engine.state.rules, state.rules)
        XCTAssertEqual(engine.state.settings, state.settings)
        XCTAssertEqual(engine.state.dailySummary(for: start).totalSeconds, 13)
        XCTAssertEqual(engine.state.dailySummary(for: start).leisureSeconds, 0)
        XCTAssertTrue(engine.state.dailySummary(for: start).ranking.allSatisfy { $0.target.kind == .application })
    }

    func testLeisureAccumulatesProgressAndFiresOneMilestone() {
        var state = makeState(category: .leisure)
        state.settings.progressThresholdSeconds = 60
        state.progressSeconds = 58
        var engine = TrackingEngine(state: state)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = ActivitySample(applicationName: "Editor")

        _ = engine.update(sample: sample, now: start)
        XCTAssertFalse(engine.update(sample: sample, now: start.addingTimeInterval(1)).celebrationTriggered)
        let milestone = engine.update(sample: sample, now: start.addingTimeInterval(2))

        XCTAssertTrue(milestone.celebrationTriggered)
        XCTAssertEqual(engine.state.progressSeconds, 0)
        XCTAssertTrue(engine.state.celebrationPending)
        XCTAssertEqual(engine.state.dailySummary(for: start).leisureSeconds, 2)
    }

    func testIgnoredActivityIsVisibleButNotRecorded() {
        let state = makeState(category: .ignored)
        var engine = TrackingEngine(state: state)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let sample = ActivitySample(applicationName: "Private App")

        _ = engine.update(sample: sample, now: start)
        let update = engine.update(sample: sample, now: start.addingTimeInterval(1))

        XCTAssertEqual(update.currentActivity.category, .ignored)
        XCTAssertTrue(engine.state.records.isEmpty)
        XCTAssertEqual(engine.state.dailySummary(for: start).totalSeconds, 0)
    }

    func testManualRecoveryStaysPausedUntilExplicitResume() {
        var state = makeState(category: .focus)
        state.settings.idleThresholdSeconds = 300
        state.settings.recoveryMode = .manual
        var engine = TrackingEngine(state: state)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let active = ActivitySample(applicationName: "Editor")
        let idle = ActivitySample(applicationName: "Editor", idleSeconds: 300)

        _ = engine.update(sample: active, now: start)
        XCTAssertEqual(engine.update(sample: idle, now: start.addingTimeInterval(1)).status, .resumeRequired)
        XCTAssertEqual(engine.update(sample: active, now: start.addingTimeInterval(2)).status, .resumeRequired)
        engine.resumeByUser(at: start.addingTimeInterval(2))
        _ = engine.update(sample: active, now: start.addingTimeInterval(3))
        _ = engine.update(sample: active, now: start.addingTimeInterval(4))

        XCTAssertEqual(engine.status, .recording)
        XCTAssertEqual(engine.state.dailySummary(for: start).focusSeconds, 2)
    }

    func testAutomaticRecoveryResumesOnActivity() {
        var state = makeState(category: .focus)
        state.settings.recoveryMode = .automatic
        var engine = TrackingEngine(state: state)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let active = ActivitySample(applicationName: "Editor")
        let idle = ActivitySample(applicationName: "Editor", idleSeconds: 300)

        _ = engine.update(sample: active, now: start)
        _ = engine.update(sample: idle, now: start.addingTimeInterval(1))
        XCTAssertEqual(engine.update(sample: active, now: start.addingTimeInterval(2)).status, .recording)
    }

    func testClearingHistoryPreservesRulesAndSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = UsageRepository(fileURL: directory.appendingPathComponent("usage.json"))
        var state = makeState(category: .focus)
        state.settings.notificationsEnabled = true
        state.progressSeconds = 42
        state.records = [ActivityRecord(day: Date(), target: .init(kind: .application, name: "Editor"), category: .focus, durationSeconds: 12)]

        let cleared = try repository.clearHistory(from: state)

        XCTAssertTrue(cleared.records.isEmpty)
        XCTAssertEqual(cleared.rules, state.rules)
        XCTAssertEqual(cleared.settings, state.settings)
        XCTAssertEqual(cleared.progressSeconds, 42)
        XCTAssertEqual(try repository.load(), cleared)
    }

    func testRetentionPurgesOldRecordsAndKeepsRecentRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = UsageRepository(fileURL: directory.appendingPathComponent("usage.json"))
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = makeState(category: .focus)
        state.settings.retentionPeriod = .thirtyDays
        state.records = [
            ActivityRecord(day: now.addingTimeInterval(-31 * 86_400), target: .init(kind: .application, name: "Old"), category: .focus, durationSeconds: 10),
            ActivityRecord(day: now.addingTimeInterval(-2 * 86_400), target: .init(kind: .application, name: "Recent"), category: .focus, durationSeconds: 20)
        ]

        let purged = try repository.purgeExpired(in: state, now: now)

        XCTAssertEqual(purged.records.map(\.target.name), ["Recent"])
    }

    private func makeState(category: ActivityCategory) -> UsageState {
        UsageState(
            setupComplete: true,
            settings: TrackingSettings(retentionPeriod: .thirtyDays),
            rules: [ClassificationRule(target: .init(kind: .application, name: category == .ignored ? "Private App" : "Editor"), category: category)]
        )
    }
}
