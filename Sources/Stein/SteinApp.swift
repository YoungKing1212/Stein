import SwiftUI
import AppKit
import SteinCore

@main
struct SteinApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    // 通过 swift run 启动时没有 .app bundle,需要手动激活成普通应用。
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    await appState.initialLoad()
                }
        }
        .defaultSize(width: 1100, height: 720)
    }
}
