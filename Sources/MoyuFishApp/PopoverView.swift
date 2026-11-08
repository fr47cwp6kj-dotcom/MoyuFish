import SwiftUI
import MoyuFishCore

struct PopoverView: View {
    @ObservedObject var model: MoyuFishModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            FishTankView(model: model)

            if !model.state.setupComplete {
                FirstRunView(model: model)
            } else {
                currentActivity
                summary
                progress
                ranking
                controls
            }
        }
        .padding(16)
        .frame(width: 360)
        .onDisappear { model.save() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("摸鱼鱼").font(.system(size: 15, weight: .semibold))
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(model.status.title).font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("设置")
            .accessibilityLabel("设置")
        }
    }

    private var currentActivity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("当前活动").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(model.currentActivity.target?.name ?? "未识别应用")
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(model.currentActivity.category.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(categoryColor(model.currentActivity.category))
            }
            if model.currentActivity.category == .ignored {
                Text("已忽略，不计时").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let error = model.persistenceError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 0) {
            metric(title: "今日摸鱼", value: duration(model.dailySummary.leisureSeconds))
            Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1, height: 30).padding(.horizontal, 12)
            metric(title: "今日总计", value: duration(model.dailySummary.totalSeconds))
        }
        .padding(.vertical, 3)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("摸鱼进度").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(duration(model.state.progressSeconds)) / \(duration(model.state.settings.progressThresholdSeconds))")
                    .font(.system(size: 11, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(1, Double(model.state.progressSeconds) / Double(max(1, model.state.settings.progressThresholdSeconds))))
                .tint(.teal)
                .accessibilityLabel("摸鱼进度")
                .accessibilityValue("\(duration(model.state.progressSeconds)) / \(duration(model.state.settings.progressThresholdSeconds))")
        }
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("今日使用").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(model.dailySummary.ranking.count) 项").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            if model.dailySummary.ranking.isEmpty {
                Text("还没有已记录的使用时间").font(.system(size: 11)).foregroundStyle(.secondary).padding(.vertical, 5)
            } else {
                ForEach(Array(model.dailySummary.ranking.prefix(5).enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: 8) {
                        Text(entry.target.name).font(.system(size: 12)).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(entry.category.title).font(.system(size: 10)).foregroundStyle(categoryColor(entry.category))
                        Text(duration(entry.seconds)).font(.system(size: 11, design: .rounded).monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .frame(height: 20)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button {
                model.pauseOrResume()
            } label: {
                Label(model.status == .recording ? "暂停记录" : "恢复记录", systemImage: model.status == .recording ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.bordered)
            .disabled(model.status == .setupRequired || model.status == .locked)

            Spacer()
            Button("设置") { openSettings() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch model.status {
        case .recording: .teal
        case .userPaused: .orange
        case .idle, .locked, .resumeRequired: .secondary
        case .setupRequired: .gray
        }
    }

    private func categoryColor(_ category: ActivityCategory) -> Color {
        switch category {
        case .leisure: .teal
        case .focus: .blue
        case .ignored, .unclassified: .secondary
        }
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let hours = minutes / 60
        return hours > 0 ? "\(hours) 小时 \(minutes % 60) 分" : "\(minutes) 分"
    }
}

private struct FirstRunView: View {
    @ObservedObject var model: MoyuFishModel
    @State private var retention = ""
    @State private var idleMinutes = 5
    @State private var recoveryMode = RecoveryMode.manual
    @State private var thresholdMinutes = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("首次设置").font(.system(size: 14, weight: .semibold))
            Text("仅记录前台应用的使用时长，活动记录只保存在这台 Mac。")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            Picker("记录保留", selection: $retention) {
                Text("请选择保留周期").tag("")
                ForEach(RetentionPeriod.allCases) { period in Text(period.title).tag(period.rawValue) }
            }
            Stepper("空闲判定：\(idleMinutes) 分钟", value: $idleMinutes, in: 1...60)
            Picker("恢复方式", selection: $recoveryMode) {
                ForEach(RecoveryMode.allCases) { Text($0.title).tag($0) }
            }
            Stepper("摸鱼提醒：\(thresholdMinutes) 分钟", value: $thresholdMinutes, in: 1...180)

            Text("分类列表为空。你可以在设置中手动添加应用分类规则。")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("开始记录") {
                guard let period = RetentionPeriod(rawValue: retention) else { return }
                model.completeSetup(retention: period, idleMinutes: idleMinutes, recoveryMode: recoveryMode, progressMinutes: thresholdMinutes)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .disabled(RetentionPeriod(rawValue: retention) == nil)
        }
        .font(.system(size: 12))
        .onAppear {
            idleMinutes = max(1, model.state.settings.idleThresholdSeconds / 60)
            thresholdMinutes = max(1, model.state.settings.progressThresholdSeconds / 60)
            recoveryMode = model.state.settings.recoveryMode
        }
    }
}
