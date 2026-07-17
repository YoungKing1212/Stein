import SwiftUI
import SteinCore

/// 服务页:brew services 列表,启动/停止/重启。
struct ServicesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(appState.services.items) { item in
            HStack {
                StatusBadge(status: item.status)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).fontWeight(.medium)
                    if let user = item.user {
                        Text("用户:\(user)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    if item.isRunning {
                        actionButton("停止", icon: "stop.circle", action: "stop", name: item.name)
                    } else {
                        actionButton("启动", icon: "play.circle", action: "start", name: item.name)
                    }
                    actionButton("重启", icon: "arrow.clockwise.circle", action: "restart", name: item.name)
                }
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("服务")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await appState.refreshServices() }
                } label: {
                    if appState.services.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(appState.services.isLoading)
            }
        }
        .overlay {
            if appState.services.items.isEmpty && !appState.services.isLoading {
                ContentUnavailableView(
                    "没有可用的服务",
                    systemImage: "gearshape.2",
                    description: Text("安装了带服务的 formula(如 mysql、redis)后会出现在这里。")
                )
            }
        }
    }

    private func actionButton(_ title: String, icon: String, action: String, name: String) -> some View {
        Button {
            Task { await appState.performService(action, on: name) }
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.borderless)
        .disabled(appState.commandCenter.isRunning)
    }
}

struct StatusBadge: View {
    let status: String?

    private var color: Color {
        switch status {
        case "started": return .green
        case "error": return .red
        case "stopped": return .gray
        default: return .secondary
        }
    }

    private var text: String {
        switch status {
        case "started": return "运行中"
        case "error": return "错误"
        case "stopped": return "已停止"
        case "none", nil: return "未注册"
        default: return status ?? "未知"
        }
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
