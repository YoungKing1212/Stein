import SwiftUI
import SteinCore

/// 已安装包列表:formulae / casks 分组,支持过滤,选中后在右侧 inspector 展示详情。
struct InstalledView: View {
    @Environment(AppState.self) private var appState
    @State private var selected: BrewPackage?
    @State private var filterText = ""

    private var filteredFormulae: [BrewPackage] {
        filter(appState.installed.formulae)
    }

    private var filteredCasks: [BrewPackage] {
        filter(appState.installed.casks)
    }

    private func filter(_ packages: [BrewPackage]) -> [BrewPackage] {
        guard !filterText.isEmpty else { return packages }
        return packages.filter {
            $0.id.localizedCaseInsensitiveContains(filterText)
                || ($0.desc?.localizedCaseInsensitiveContains(filterText) ?? false)
        }
    }

    var body: some View {
        List(selection: $selected) {
            Section("Formulae (\(filteredFormulae.count))") {
                ForEach(filteredFormulae) { package in
                    PackageRow(package: package).tag(package)
                }
            }
            Section("Casks (\(filteredCasks.count))") {
                ForEach(filteredCasks) { package in
                    PackageRow(package: package).tag(package)
                }
            }
        }
        .searchable(text: $filterText, prompt: "过滤已安装包")
        .navigationTitle("已安装")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await appState.loadInstalled() }
                } label: {
                    if appState.installed.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(appState.installed.isLoading)
            }
        }
        .inspector(isPresented: .constant(selected != nil)) {
            if let selected {
                PackageDetailView(package: selected) {
                    self.selected = nil
                }
                .inspectorColumnWidth(min: 280, ideal: 320, max: 400)
            }
        }
        .overlay {
            if appState.installed.packages.isEmpty && !appState.installed.isLoading {
                ContentUnavailableView("没有已安装的包", systemImage: "shippingbox")
            }
        }
    }
}

/// 列表行:名称、版本、描述、过期标记。搜索页与已安装页共用。
struct PackageRow: View {
    let package: BrewPackage
    var trailing: AnyView?

    init(package: BrewPackage, trailing: AnyView? = nil) {
        self.package = package
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.displayName).fontWeight(.medium)
                    Text(package.kind.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                    if package.isOutdated {
                        Label("可更新", systemImage: "arrow.up.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if package.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let desc = package.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let version = package.installedVersion {
                Text(version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            trailing
        }
        .padding(.vertical, 2)
    }
}
