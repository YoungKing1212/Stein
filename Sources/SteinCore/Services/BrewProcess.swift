import Foundation

public enum BrewError: Error, LocalizedError, Sendable {
    case brewNotFound
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .brewNotFound:
            return "未找到 brew 可执行文件(已检查 /opt/homebrew/bin 与 /usr/local/bin)。请先安装 Homebrew。"
        case let .commandFailed(command, exitCode, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "命令 `brew \(command)` 失败,退出码 \(exitCode)。"
                : "命令 `brew \(command)` 失败(退出码 \(exitCode)):\(detail)"
        case let .decodingFailed(context):
            return "解析 brew 输出失败:\(context)"
        }
    }
}

/// 探测本机 brew 可执行文件路径(GUI/独立进程 PATH 里通常没有 brew)。
public enum BrewPath {
    public static let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    public static func resolve() -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

/// 对 `Process` 调用 brew 的底层封装。
public enum BrewProcess {
    /// 保证 brew 的子进程能找到所需工具的最小环境补充。
    private static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let brewDir = (BrewPath.resolve() as NSString?)?.deletingLastPathComponent ?? "/opt/homebrew/bin"
        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        if !existing.contains(brewDir) {
            env["PATH"] = "\(brewDir):\(existing)"
        }
        return env
    }

    /// 执行 brew 并收集全部 stdout/stderr,用于 JSON 查询。
    public static func output(_ args: [String], extraEnv: [String: String] = [:]) async throws -> (stdout: Data, stderr: String, status: Int32) {
        guard let brew = BrewPath.resolve() else { throw BrewError.brewNotFound }
        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = args
            var env = environment()
            env.merge(extraEnv) { _, new in new }
            process.environment = env

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            try process.run()
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (outData, String(decoding: errData, as: UTF8.self), process.terminationStatus)
        }.value
    }

    /// 执行 brew 并把 stdout+stderr(合并为同一管道,保持交错顺序)逐行回调给 onLine,用于长时间写操作。
    /// 返回进程退出码;启动失败抛错。
    @discardableResult
    public static func stream(
        _ args: [String],
        onLine: @MainActor @Sendable @escaping (String) -> Void
    ) async throws -> Int32 {
        guard let brew = BrewPath.resolve() else { throw BrewError.brewNotFound }
        return try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = args
            process.environment = environment()

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            try process.run()

            let handle = pipe.fileHandleForReading
            var buffer = Data()
            // read(upToCount:) 阻塞读取;返回 nil 或空表示 EOF(进程关闭管道)。
            while let chunk = try? handle.read(upToCount: 4096), !chunk.isEmpty {
                buffer.append(chunk)
                while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[..<newlineIndex]
                    buffer = buffer[(buffer.index(after: newlineIndex))...]
                    let line = String(decoding: lineData, as: UTF8.self)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
                    await onLine(line)
                }
            }
            if !buffer.isEmpty {
                let line = String(decoding: buffer, as: UTF8.self)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
                if !line.isEmpty { await onLine(line) }
            }
            process.waitUntilExit()
            return process.terminationStatus
        }.value
    }
}
