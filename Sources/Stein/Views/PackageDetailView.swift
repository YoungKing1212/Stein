import SwiftUI
import SteinCore

/// 包详情面板:描述、主页、版本、依赖,以及安装/卸载/更新操作。
struct PackageDetailView: View {
    @Environment(AppState.self) private var appState

    let package: BrewPackage
    var onClose: () -> Void

    @State private var showUninstallConfirm = false

    /// 以 AppState 中的最新数据为准(操作完成后刷新),取不到时退回传入的快照。
    private var current: BrewPackage {
        appState.installed.packages.first { $0.id == package.id } ?? package
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                Divider()

                if let desc = current.desc, !desc.isEmpty {
                    Text(desc).font(.callout)
                }
                if let homepage = current.homepage, let url = URL(string: homepage) {
                    Link(homepage, destination: url)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                versionInfo
                if !current.dependencies.isEmpty { dependenciesInfo }
                if let caveats = current.caveats, !caveats.isEmpty {
                    LabeledContent("Caveats") {
                        Text(caveats).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Divider()
                actions
            }
            .padding()
        }
        .toolbar {
            ToolbarItem {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var header: some View {
        HStack {
            Text(current.displayName).font(.title2).fontWeight(.semibold)
            Text(current.kind.rawValue)
                .font(.caption2)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
        }
    }

    private var versionInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let installed = current.installedVersion {
                LabeledContent("已安装版本") {
                    Text(installed).monospaced()
                }
            }
            if let latest = current.latestVersion {
                LabeledContent("最新版本") {
                    HStack(spacing: 4) {
                        Text(latest).monospaced()
                        if current.isOutdated {
                            Text("可更新")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            if current.pinned {
                Label("已 pin,不会被 upgrade 更新", systemImage: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dependenciesInfo: some View {
        LabeledContent("依赖") {
            Text(current.dependencies.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actions: some View {
        let busy = appState.commandCenter.isRunning
        HStack(spacing: 10) {
            if current.isInstalled {
                if current.isOutdated && !current.pinned {
                    Button {
                        Task { await appState.upgrade(name: current.id) }
                    } label: {
                        Label("更新", systemImage: "arrow.up.circle")
                    }
                    .disabled(busy)
                }
                Button(role: .destructive) {
                    showUninstallConfirm = true
                } label: {
                    Label("卸载", systemImage: "trash")
                }
                .disabled(busy)
            } else {
                Button {
                    Task { await appState.install(current) }
                } label: {
                    Label("安装", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
            }
        }
        .confirmationDialog(
            "确定卸载 \(current.displayName) 吗?",
            isPresented: $showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button("卸载", role: .destructive) {
                Task { await appState.uninstall(current) }
            }
            Button("取消", role: .cancel) {}
        }
    }
}
