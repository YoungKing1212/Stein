import SwiftUI
import SteinCore

/// 更新页:outdated 列表,支持单个升级与全部升级。
struct UpdatesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(appState.updates.items) { item in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.entry.name).fontWeight(.medium)
                        Text(item.kind.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                        if item.entry.pinned == true {
                            Label("已 pin", systemImage: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("\(item.installed) → \(item.current)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                Spacer()
                if item.entry.pinned != true {
                    Button {
                        Task { await appState.upgrade(name: item.entry.name) }
                    } label: {
                        Label("更新", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(appState.commandCenter.isRunning)
                }
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("更新")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await appState.updateMetadata() }
                } label: {
                    Label("刷新元数据", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("执行 brew update,然后重新检查可更新的包")
                .disabled(appState.commandCenter.isRunning)
            }
            ToolbarItem {
                Button {
                    Task { await appState.refreshUpdates() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(appState.updates.isLoading)
            }
            ToolbarItem {
                Button {
                    Task { await appState.upgradeAll() }
                } label: {
                    Label("全部更新", systemImage: "arrow.up.to.line")
                }
                .disabled(appState.updates.items.isEmpty || appState.commandCenter.isRunning)
            }
        }
        .overlay {
            if appState.updates.isLoading && appState.updates.items.isEmpty {
                ProgressView("检查更新中…")
            } else if appState.updates.items.isEmpty {
                ContentUnavailableView("全部包都是最新的", systemImage: "checkmark.circle")
            }
        }
    }
}
