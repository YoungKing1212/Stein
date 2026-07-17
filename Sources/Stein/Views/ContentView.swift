import SwiftUI
import SteinCore

enum SidebarSection: String, CaseIterable, Identifiable {
    case installed = "已安装"
    case search = "搜索"
    case updates = "更新"
    case services = "服务"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .installed: return "shippingbox"
        case .search: return "magnifyingglass"
        case .updates: return "arrow.triangle.2.circlepath"
        case .services: return "gearshape.2"
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: SidebarSection? = .installed

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(selection: $selection) {
                    ForEach(SidebarSection.allCases) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .badge(section == .updates && !appState.updates.items.isEmpty
                                   ? appState.updates.items.count : 0)
                            .tag(section)
                    }
                }
                .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            } detail: {
                detailView
            }

            Divider()
            OutputConsoleView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            if let message = appState.errorMessage {
                ErrorBanner(message: message) {
                    appState.errorMessage = nil
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .installed {
        case .installed: InstalledView()
        case .search: SearchView()
        case .updates: UpdatesView()
        case .services: ServicesView()
        }
    }
}

struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).lineLimit(2)
            Spacer()
            Button("关闭", action: dismiss)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(.white)
        .shadow(radius: 4)
    }
}
