import Foundation
import Observation

/// 全局写操作中心:所有 install/uninstall/upgrade/services 操作都经此执行,
/// 输出汇入控制台供 UI 实时展示。
@MainActor
@Observable
public final class CommandCenter {
    public private(set) var lines: [String] = []
    public private(set) var isRunning = false
    /// 当前正在执行的命令描述,用于 UI 展示。
    public private(set) var currentCommand: String?
    /// 控制台是否展开(由 View 绑定)。
    public var isExpanded = false

    public init() {}

    /// 执行 `brew <args>` 并流式收集输出。返回是否成功(退出码为 0)。
    @discardableResult
    public func run(_ args: [String]) async -> Bool {
        guard !isRunning else {
            appendLine("⚠️ 已有命令在执行中,忽略:brew \(args.joined(separator: " "))")
            return false
        }
        isRunning = true
        isExpanded = true
        currentCommand = "brew \(args.joined(separator: " "))"
        appendLine("$ \(currentCommand!)")
        defer {
            isRunning = false
            currentCommand = nil
        }
        do {
            let status = try await BrewProcess.stream(args) { [weak self] line in
                self?.appendLine(line)
            }
            appendLine(status == 0 ? "✅ 完成" : "❌ 失败,退出码 \(status)")
            return status == 0
        } catch {
            appendLine("❌ \(error.localizedDescription)")
            return false
        }
    }

    public func clear() {
        lines.removeAll()
    }

    private func appendLine(_ line: String) {
        lines.append(line)
        // 防止长时间安装产生无限增长的日志。
        if lines.count > 5000 {
            lines.removeFirst(lines.count - 5000)
        }
    }
}
