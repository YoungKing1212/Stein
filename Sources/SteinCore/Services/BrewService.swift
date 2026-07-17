import Foundation

/// brew 只读查询层。所有查询都走 `--json=v2` 或 `--json` 输出并 Codable 解码。
public struct BrewService: Sendable {
    public init() {}

    // MARK: - 已安装包

    /// `brew info --json=v2 --installed` + `brew outdated --json=v2`,合并为统一模型列表。
    public func installedPackages() async throws -> [BrewPackage] {
        async let infoTask = runJSON(["info", "--json=v2", "--installed"], as: InstalledResponse.self)
        async let outdatedTask = runJSON(["outdated", "--json=v2"], as: OutdatedResponse.self)
        let info = try await infoTask
        let outdated = (try? await outdatedTask) ?? OutdatedResponse(formulae: [], casks: [])
        return merge(info: info, outdated: outdated)
    }

    /// 把 info 响应与 outdated 响应合并成统一的 BrewPackage 列表。单独提出来便于测试。
    public func merge(info: InstalledResponse, outdated: OutdatedResponse) -> [BrewPackage] {
        let outdatedFormulae = Dictionary(uniqueKeysWithValues: outdated.formulae.map { ($0.name, $0) })
        let outdatedCasks = Dictionary(uniqueKeysWithValues: outdated.casks.map { ($0.name, $0) })
        let formulae = info.formulae.map { BrewPackage(formula: $0, outdatedEntry: outdatedFormulae[$0.name]) }
        let casks = info.casks.map { BrewPackage(cask: $0, outdatedEntry: outdatedCasks[$0.token]) }
        return formulae + casks
    }

    // MARK: - 过期包

    public func outdated() async throws -> OutdatedResponse {
        try await runJSON(["outdated", "--json=v2"], as: OutdatedResponse.self)
    }

    // MARK: - 搜索

    /// `brew search --formula/--cask <term>` 分别取两类名称,再 `brew info --json=v2 <names>` 取详情。
    public func search(term: String) async throws -> [BrewPackage] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // brew 6 起,`brew search` 纯文本输出为无分段标题的裸名称列表,
        // 无法用 `==> Formulae` 区分类型,因此分两次查询。
        async let formulaTask = BrewProcess.output(
            ["search", "--formula", trimmed],
            extraEnv: ["HOMEBREW_NO_AUTO_UPDATE": "1"]
        )
        async let caskTask = BrewProcess.output(
            ["search", "--cask", trimmed],
            extraEnv: ["HOMEBREW_NO_AUTO_UPDATE": "1"]
        )
        let formulaNames = Self.parseNameList(String(decoding: try await formulaTask.stdout, as: UTF8.self))
        let caskTokens = Self.parseNameList(String(decoding: try await caskTask.stdout, as: UTF8.self))
        // 限制详情查询数量,避免一次 info 拉取过多。
        let names = Array((formulaNames + caskTokens).prefix(40))
        guard !names.isEmpty else { return [] }

        let (infoOut, _, _) = try await BrewProcess.output(
            ["info", "--json=v2"] + names,
            extraEnv: ["HOMEBREW_NO_AUTO_UPDATE": "1"]
        )
        guard let info: InstalledResponse = try Self.decodeAllowingPartial(infoOut) else {
            // info 失败时退化为只显示名称。
            return names.map {
                BrewPackage(
                    kind: caskTokens.contains($0) ? .cask : .formula,
                    id: $0, displayName: $0, desc: nil, homepage: nil,
                    installedVersion: nil, latestVersion: nil, isOutdated: false,
                    pinned: false, installedOnRequest: false, dependencies: [], caveats: nil
                )
            }
        }
        return info.formulae.map { BrewPackage(formula: $0) } + info.casks.map { BrewPackage(cask: $0) }
    }

    /// 解析 `brew search --formula/--cask` 的裸名称列表输出(brew 6 起无 `==>` 分段标题)。
    /// 忽略空行与偶发的 `==>` 标题行。
    public static func parseNameList(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("==>") }
    }

    // MARK: - 服务

    public func services() async throws -> [BrewServiceItem] {
        let (stdout, stderr, status) = try await BrewProcess.output(["services", "list", "--json"])
        // 未安装任何带服务的 formula 时,brew 可能返回空输出或非零退出。
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        guard let items = try Self.decodeAllowingPartial(stdout, as: [BrewServiceItem].self) else {
            if status != 0 { return [] }
            throw BrewError.decodingFailed("brew services list: \(stderr.prefix(200))")
        }
        return items
    }

    // MARK: - JSON 工具

    /// 查询类命令统一加 HOMEBREW_NO_AUTO_UPDATE,避免每次查询都触发更新检查。
    private func runJSON<T: Decodable>(_ args: [String], as type: T.Type) async throws -> T {
        let (stdout, stderr, status) = try await BrewProcess.output(
            args,
            extraEnv: ["HOMEBREW_NO_AUTO_UPDATE": "1"]
        )
        if let value = try Self.decodeAllowingPartial(stdout, as: T.self) {
            return value
        }
        if status != 0 {
            throw BrewError.commandFailed(command: args.joined(separator: " "), exitCode: status, stderr: stderr)
        }
        throw BrewError.decodingFailed("brew \(args.joined(separator: " ")) 输出不是有效 JSON")
    }

    /// 从 stdout 中提取第一个 `{`/`[` 起的 JSON 并解码;失败返回 nil 而不是抛出,便于调用方兜底。
    /// (brew 偶尔会在 stdout 前打印提示行,且部分名字无效时 info 仍输出有效 JSON 但退出码非零。)
    public static func decodeAllowingPartial<T: Decodable>(_ data: Data, as type: T.Type = T.self) throws -> T? {
        guard let start = data.firstIndex(where: { $0 == UInt8(ascii: "{") || $0 == UInt8(ascii: "[") }) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data[start...])
    }
}

private extension Data {
    func trimmingCharacters(in set: CharacterSet) -> Data {
        guard let string = String(data: self, encoding: .utf8) else { return self }
        return Data(string.trimmingCharacters(in: set).utf8)
    }
}
