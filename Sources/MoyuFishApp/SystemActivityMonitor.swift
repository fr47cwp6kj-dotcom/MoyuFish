import AppKit
import CoreGraphics
import Foundation
import MoyuFishCore

@MainActor
final class SystemActivityMonitor {
    private(set) var isLocked = false
    private(set) var isSleeping = false
    private var observers: [NSObjectProtocol] = []

    init() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        observers.append(workspaceCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isSleeping = true }
        })
        observers.append(workspaceCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isSleeping = false }
        })
        observers.append(workspaceCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isLocked = true }
        })
        observers.append(workspaceCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isLocked = false }
        })

        let distributedCenter = DistributedNotificationCenter.default()
        observers.append(distributedCenter.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isLocked = true }
        })
        observers.append(distributedCenter.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isLocked = false }
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.forEach(DistributedNotificationCenter.default().removeObserver)
    }

    func sample() -> ActivitySample {
        let application = NSWorkspace.shared.frontmostApplication
        let appName = application?.localizedName ?? "未知应用"
        let idle = [
            CGEventType.mouseMoved,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .keyDown,
            .flagsChanged,
            .scrollWheel
        ].map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }.min() ?? 0
        return ActivitySample(
            applicationName: appName,
            idleSeconds: idle,
            isLocked: isLocked,
            isSleeping: isSleeping,
            isMoyuFish: application?.bundleIdentifier == Bundle.main.bundleIdentifier
        )
    }

}
