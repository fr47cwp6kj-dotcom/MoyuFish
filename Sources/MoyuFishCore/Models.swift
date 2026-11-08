import Foundation

public enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case leisure
    case focus
    case ignored
    case unclassified

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .leisure: "摸鱼"
        case .focus: "专注"
        case .ignored: "忽略"
        case .unclassified: "未分类"
        }
    }
}

public enum TargetKind: String, Codable {
    case application
    // Decode legacy website records/rules without discarding saved user state.
    case domain
}

public struct ActivityTarget: Codable, Hashable, Identifiable {
    public let kind: TargetKind
    public let name: String

    public var id: String { "\(kind.rawValue):\(name)" }

    public init(kind: TargetKind, name: String) {
        self.kind = kind
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct ClassificationRule: Codable, Identifiable, Hashable {
    public var target: ActivityTarget
    public var category: ActivityCategory

    public var id: String { target.id }

    public init(target: ActivityTarget, category: ActivityCategory) {
        self.target = target
        self.category = category
    }
}

public enum RecoveryMode: String, Codable, CaseIterable, Identifiable {
    case manual
    case automatic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .manual: "手动恢复"
        case .automatic: "自动恢复"
        }
    }
}

public enum RetentionPeriod: String, Codable, CaseIterable, Identifiable {
    case thirtyDays
    case ninetyDays
    case forever

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .thirtyDays: "30 天"
        case .ninetyDays: "90 天"
        case .forever: "永久"
        }
    }

    public var days: Int? {
        switch self {
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .forever: nil
        }
    }
}

public struct TrackingSettings: Codable, Equatable {
    public var idleThresholdSeconds: Int
    public var recoveryMode: RecoveryMode
    public var progressThresholdSeconds: Int
    public var retentionPeriod: RetentionPeriod?
    public var notificationsEnabled: Bool

    public init(
        idleThresholdSeconds: Int = 300,
        recoveryMode: RecoveryMode = .manual,
        progressThresholdSeconds: Int = 1_800,
        retentionPeriod: RetentionPeriod? = nil,
        notificationsEnabled: Bool = false
    ) {
        self.idleThresholdSeconds = max(60, idleThresholdSeconds)
        self.recoveryMode = recoveryMode
        self.progressThresholdSeconds = max(60, progressThresholdSeconds)
        self.retentionPeriod = retentionPeriod
        self.notificationsEnabled = notificationsEnabled
    }
}

public struct ActivityRecord: Codable, Hashable, Identifiable {
    public let day: Date
    public let target: ActivityTarget
    public let category: ActivityCategory
    public var durationSeconds: Int

    public var id: String {
        "\(day.timeIntervalSince1970):\(target.id):\(category.rawValue)"
    }

    public init(day: Date, target: ActivityTarget, category: ActivityCategory, durationSeconds: Int) {
        self.day = Calendar.current.startOfDay(for: day)
        self.target = target
        self.category = category
        self.durationSeconds = max(0, durationSeconds)
    }
}

public struct UsageState: Codable, Equatable {
    public var setupComplete: Bool
    public var settings: TrackingSettings
    public var rules: [ClassificationRule]
    public var records: [ActivityRecord]
    public var progressSeconds: Int
    public var celebrationPending: Bool

    public init(
        setupComplete: Bool = false,
        settings: TrackingSettings = TrackingSettings(),
        rules: [ClassificationRule] = [],
        records: [ActivityRecord] = [],
        progressSeconds: Int = 0,
        celebrationPending: Bool = false
    ) {
        self.setupComplete = setupComplete
        self.settings = settings
        self.rules = rules
        self.records = records
        self.progressSeconds = max(0, progressSeconds)
        self.celebrationPending = celebrationPending
    }
}

public struct ActivitySample: Equatable {
    public var applicationName: String
    public var idleSeconds: TimeInterval
    public var isLocked: Bool
    public var isSleeping: Bool
    public var isMoyuFish: Bool

    public init(
        applicationName: String,
        idleSeconds: TimeInterval = 0,
        isLocked: Bool = false,
        isSleeping: Bool = false,
        isMoyuFish: Bool = false
    ) {
        self.applicationName = applicationName
        self.idleSeconds = idleSeconds
        self.isLocked = isLocked
        self.isSleeping = isSleeping
        self.isMoyuFish = isMoyuFish
    }
}

public enum TrackingStatus: Equatable {
    case setupRequired
    case recording
    case userPaused
    case idle
    case locked
    case resumeRequired

    public var title: String {
        switch self {
        case .setupRequired: "需要完成设置"
        case .recording: "正在记录"
        case .userPaused: "已手动暂停"
        case .idle: "系统空闲"
        case .locked: "屏幕已锁定或睡眠"
        case .resumeRequired: "等待手动恢复"
        }
    }
}

public struct CurrentActivity: Equatable {
    public var target: ActivityTarget?
    public var category: ActivityCategory

    public init(target: ActivityTarget? = nil, category: ActivityCategory = .unclassified) {
        self.target = target
        self.category = category
    }
}

public struct EngineUpdate: Equatable {
    public var status: TrackingStatus
    public var currentActivity: CurrentActivity
    public var celebrationTriggered: Bool
}

public struct DailySummary: Equatable {
    public var totalSeconds: Int
    public var leisureSeconds: Int
    public var focusSeconds: Int
    public var unclassifiedSeconds: Int
    public var ranking: [(target: ActivityTarget, category: ActivityCategory, seconds: Int)]

    public static func == (lhs: DailySummary, rhs: DailySummary) -> Bool {
        lhs.totalSeconds == rhs.totalSeconds &&
        lhs.leisureSeconds == rhs.leisureSeconds &&
        lhs.focusSeconds == rhs.focusSeconds &&
        lhs.unclassifiedSeconds == rhs.unclassifiedSeconds &&
        lhs.ranking.elementsEqual(rhs.ranking, by: { $0.target == $1.target && $0.category == $1.category && $0.seconds == $1.seconds })
    }
}
