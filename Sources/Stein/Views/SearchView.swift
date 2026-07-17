import SwiftUI
import SteinCore

/// 搜索页:输入即搜(去抖),结果内联安装/卸载按钮。
struct SearchView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var search = appState.search

        List(appState.search.results) { package in
            PackageRow(package: package, trailing: AnyView(actionButton(for: package)))
        }
        .searchable(text: $search.query, prompt: "搜索 formulae 和 casks")
        .task(id: appState.search.query) {
            await appState.search.search()
        }
        .navigationTitle("搜索")
        .overlay {
            overlayContent
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        if appState.search.isSearching {
            ProgressView("搜索中…")
        } else if appState.search.query.isEmpty {
            ContentUnavailableView("搜索 Homebrew 包", systemImage: "magnifyingglass")
        } else if appState.search.results.isEmpty && appState.search.hasSearched {
            ContentUnavailableView.search(text: appState.search.query)
        }
    }

    @ViewBuilder
    private func actionButton(for package: BrewPackage) -> some View {
        let installed = appState.installed.isInstalled(package.id)
        let busy = appState.commandCenter.isRunning
        if installed {
            Text("已安装")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Button {
                Task { await appState.install(package) }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.borderless)
            .help("安装 \(package.id)")
            .disabled(busy)
        }
    }
}
