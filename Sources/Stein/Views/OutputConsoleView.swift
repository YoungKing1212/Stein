import SwiftUI
import SteinCore

/// 底部抽屉式控制台:展示所有写操作的实时输出。
struct OutputConsoleView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var center = appState.commandCenter

        VStack(spacing: 0) {
            HStack {
                Button {
                    center.isExpanded.toggle()
                } label: {
                    Label("控制台", systemImage: center.isExpanded ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)

                if let command = appState.commandCenter.currentCommand {
                    Text(command)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if appState.commandCenter.isRunning {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button("清空") { appState.commandCenter.clear() }
                    .buttonStyle(.borderless)
                    .disabled(appState.commandCenter.lines.isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if center.isExpanded {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(appState.commandCenter.lines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .onChange(of: appState.commandCenter.lines.count) { _, _ in
                        if let last = appState.commandCenter.lines.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }
}
