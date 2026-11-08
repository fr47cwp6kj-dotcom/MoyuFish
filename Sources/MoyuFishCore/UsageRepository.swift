import Foundation

public struct UsageRepository {
    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public static func applicationDefault(fileManager: FileManager = .default) throws -> UsageRepository {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("MoyuFish", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        return UsageRepository(fileURL: directory.appendingPathComponent("usage.json"), fileManager: fileManager)
    }

    public func load() throws -> UsageState {
        guard fileManager.fileExists(atPath: fileURL.path) else { return UsageState() }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(UsageState.self, from: data)
    }

    public func save(_ state: UsageState) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    public func clearHistory(from state: UsageState) throws -> UsageState {
        var updated = state
        updated.records.removeAll()
        try save(updated)
        return updated
    }

    public func purgeExpired(in state: UsageState, now: Date = Date(), calendar: Calendar = .current) throws -> UsageState {
        var updated = state
        if let days = updated.settings.retentionPeriod?.days {
            let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? .distantPast
            updated.records.removeAll { $0.day < cutoff }
        }
        try save(updated)
        return updated
    }
}

public extension UsageState {
    func dailySummary(for date: Date = Date(), calendar: Calendar = .current) -> DailySummary {
        let day = calendar.startOfDay(for: date)
        let today = records.filter { calendar.isDate($0.day, inSameDayAs: day) && $0.category != .ignored && $0.target.kind == .application }
        let total = today.reduce(0) { $0 + $1.durationSeconds }
        let leisure = today.filter { $0.category == .leisure }.reduce(0) { $0 + $1.durationSeconds }
        let focus = today.filter { $0.category == .focus }.reduce(0) { $0 + $1.durationSeconds }
        let unclassified = today.filter { $0.category == .unclassified }.reduce(0) { $0 + $1.durationSeconds }
        let grouped = Dictionary(grouping: today, by: { "\($0.target.id)|\($0.category.rawValue)" })
            .values
            .compactMap { entries -> (target: ActivityTarget, category: ActivityCategory, seconds: Int)? in
                guard let first = entries.first else { return nil }
                return (first.target, first.category, entries.reduce(0) { $0 + $1.durationSeconds })
            }
            .sorted { $0.seconds > $1.seconds }
        return DailySummary(
            totalSeconds: total,
            leisureSeconds: leisure,
            focusSeconds: focus,
            unclassifiedSeconds: unclassified,
            ranking: grouped
        )
    }
}
