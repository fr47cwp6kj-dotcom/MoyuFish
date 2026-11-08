import SwiftUI

@main
struct MoyuFishApp: App {
    @StateObject private var model = MoyuFishModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
                .frame(width: 360)
        } label: {
            Image(systemName: "fish.fill")
                .accessibilityLabel("摸鱼鱼，\(model.status.title)")
                .help("摸鱼鱼 · \(model.status.title)")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(width: 520, height: 620)
        }
    }
}
