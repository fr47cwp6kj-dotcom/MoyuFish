import SwiftUI
import MoyuFishCore

struct SettingsView: View {
    @ObservedObject var model: MoyuFishModel
    @State private var settings = TrackingSettings()
    @State private var category = ActivityCategory.leisure
    @State private var targetName = ""
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("摸鱼鱼设置")
                .font(.system(size: 20, weight: .semibold))
                .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rulesSection
                    Divider()
                    trackingSection
                    Divider()
                    privacySection
                }
                .padding(.bottom, 20)
            }
        }
        .padding(22)
        .onAppear { settings = model.state.settings }
        .onChange(of: settings) { _, newValue in model.updateSettings(newValue) }
        .confirmationDialog("清空所有活动记录？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("清空活动记录", role: .destructive) { model.clearHistory() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("分类规则和设置会保留；已记录的使用时长将被删除。")
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("分类规则", detail: "按应用名称分类。浏览器也作为普通应用计时。")

            HStack(spacing: 8) {
                TextField("应用名称", text: $targetName)
                    .textFieldStyle(.roundedBorder)

                Picker("分类", selection: $category) {
                    Text(ActivityCategory.leisure.title).tag(ActivityCategory.leisure)
                    Text(ActivityCategory.focus.title).tag(ActivityCategory.focus)
                    Text(ActivityCategory.ignored.title).tag(ActivityCategory.ignored)
                }
                .labelsHidden()
                .frame(width: 104)

                Button("添加") { addRule() }
                    .disabled(targetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if applicationRules.isEmpty {
                Text("分类列表为空。未分类项目会照常计时，但不会增加摸鱼进度。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(applicationRules) { rule in
                        HStack(spacing: 8) {
                            Text("应用")
                                .font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                            Text(rule.target.name).font(.system(size: 12)).lineLimit(1)
                            Spacer()
                            Text(rule.category.title).font(.system(size: 12)).foregroundStyle(color(for: rule.category))
                            Button {
                                model.removeRule(rule)
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                            .help("删除分类规则")
                            .accessibilityLabel("删除 \(rule.target.name) 规则")
                        }
                        .frame(height: 34)
                        if rule.id != applicationRules.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var trackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("计时与提醒", detail: "系统空闲、锁屏和睡眠期间暂停计时。")

            HStack {
                Text("空闲判定").font(.system(size: 13))
                Spacer()
                Stepper("\(settings.idleThresholdSeconds / 60) 分钟", value: Binding(
                    get: { max(1, settings.idleThresholdSeconds / 60) },
                    set: { settings.idleThresholdSeconds = $0 * 60 }
                ), in: 1...60)
                .frame(width: 170)
            }

            HStack {
                Text("空闲后恢复").font(.system(size: 13))
                Spacer()
                Picker("空闲后恢复", selection: $settings.recoveryMode) {
                    ForEach(RecoveryMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 170)
            }

            HStack {
                Text("摸鱼进度阈值").font(.system(size: 13))
                Spacer()
                Stepper("\(settings.progressThresholdSeconds / 60) 分钟", value: Binding(
                    get: { max(1, settings.progressThresholdSeconds / 60) },
                    set: { settings.progressThresholdSeconds = $0 * 60 }
                ), in: 1...180)
                .frame(width: 170)
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("系统通知").font(.system(size: 13))
                    Text("面板跃水效果始终保留").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("系统通知", isOn: $settings.notificationsEnabled).labelsHidden()
            }
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("隐私与数据", detail: "仅在本机保存应用名称、分类和使用时长，不读取网页。")
            HStack {
                Text("记录保留").font(.system(size: 13))
                Spacer()
                Picker("记录保留", selection: Binding(
                    get: { settings.retentionPeriod ?? .thirtyDays },
                    set: { settings.retentionPeriod = $0 }
                )) {
                    ForEach(RetentionPeriod.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 170)
                .disabled(!model.state.setupComplete)
            }
            HStack {
                Text("本机记录文件使用用户专属权限保存").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("清空历史…", role: .destructive) { showClearConfirmation = true }
                    .disabled(model.state.records.isEmpty)
            }
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 14, weight: .medium))
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var applicationRules: [ClassificationRule] {
        model.state.rules.filter { $0.target.kind == .application }
            .sorted { $0.target.name.localizedStandardCompare($1.target.name) == .orderedAscending }
    }

    private func addRule() {
        let name = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        model.addRule(target: ActivityTarget(kind: .application, name: name), category: category)
        targetName = ""
    }

    private func color(for category: ActivityCategory) -> Color {
        switch category {
        case .leisure: .teal
        case .focus: .blue
        case .ignored, .unclassified: .secondary
        }
    }
}
