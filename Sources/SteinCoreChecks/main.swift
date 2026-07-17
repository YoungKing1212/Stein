import Foundation
import SteinCore

// 零依赖测试检查器(CLT 环境无 XCTest / swift-testing)。
// 任一断言失败即以退出码 1 结束;全部通过输出 "All checks passed"。

private var failures = 0
private var passed = 0

@MainActor
private func check(_ condition: Bool, _ name: String, _ detail: String = "") {
    if condition {
        passed += 1
        print("  ✓ \(name)")
    } else {
        failures += 1
        print("  ✗ \(name)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

private func fixture(_ name: String, _ ext: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures") else {
        throw NSError(domain: "checks", code: 1, userInfo: [NSLocalizedDescriptionKey: "缺少 fixture \(name).\(ext)"])
    }
    return try Data(contentsOf: url)
}

let decoder = JSONDecoder()

// MARK: - installed.json

do {
    print("installed.json")
    let response = try decoder.decode(InstalledResponse.self, from: fixture("installed", "json"))
    check(response.formulae.count == 2, "解码出 2 个 formulae", "\(response.formulae.count)")
    check(response.casks.count == 1, "解码出 1 个 cask", "\(response.casks.count)")

    let abseil = response.formulae[0]
    check(abseil.name == "abseil", "formula name")
    check(abseil.versions?.stable == "20260107.1", "formula stable 版本", abseil.versions?.stable ?? "nil")
    check(abseil.installed?.first?.version == "20260107.1", "formula 已安装版本")
    check(abseil.installed?.first?.installedOnRequest == false, "installed_on_request")
    check(abseil.kegOnly == false, "keg_only")
    check(abseil.caveats == nil, "caveats 为 null")

    let cask = response.casks[0]
    check(cask.token == "android-platform-tools", "cask token")
    check(cask.displayName == "Android SDK Platform-Tools", "cask displayName")
    check(cask.installed == "37.0.0", "cask installed 版本", cask.installed ?? "nil")
    check(cask.outdated == true, "cask outdated")
} catch {
    check(false, "installed.json 解码", error.localizedDescription)
}

// MARK: - outdated.json

do {
    print("outdated.json")
    let response = try decoder.decode(OutdatedResponse.self, from: fixture("outdated", "json"))
    check(response.formulae.count == 2, "解码出 2 个过期 formulae")
    check(response.casks.count == 1, "解码出 1 个过期 cask")

    let git = response.formulae.first { $0.name == "git" }
    check(git?.installedVersions == ["2.52.0_1"], "installed_versions")
    check(git?.currentVersion == "2.55.0", "current_version")
    check(git?.pinned == false, "pinned=false")

    let bash = response.formulae.first { $0.name == "bash" }
    check(bash?.pinned == true, "pinned=true")
} catch {
    check(false, "outdated.json 解码", error.localizedDescription)
}

// MARK: - merge(info + outdated)

do {
    print("merge(info, outdated)")
    let info = try decoder.decode(InstalledResponse.self, from: fixture("installed", "json"))
    let outdated = try decoder.decode(OutdatedResponse.self, from: fixture("outdated", "json"))
    let packages = BrewService().merge(info: info, outdated: outdated)

    check(packages.count == 3, "合并后共 3 个包", "\(packages.count)")

    let git = packages.first { $0.id == "git" }
    check(git?.isOutdated == true, "git 标记为过期")
    check(git?.installedVersion == "2.52.0_1", "git 已安装版本")
    check(git?.latestVersion == "2.55.0", "git 最新版本取 outdated.current_version", git?.latestVersion ?? "nil")
    check(git?.installedOnRequest == true, "git installedOnRequest")

    let abseil = packages.first { $0.id == "abseil" }
    check(abseil?.isOutdated == false, "abseil 未过期")
    check(abseil?.latestVersion == "20260107.1", "abseil 最新版本取 versions.stable")

    let cask = packages.first { $0.id == "android-platform-tools" }
    check(cask?.kind == .cask, "cask kind")
    check(cask?.isOutdated == true, "cask 标记为过期")
    check(cask?.latestVersion == "37.0.1", "cask 最新版本")
} catch {
    check(false, "merge", error.localizedDescription)
}

// MARK: - services.json

do {
    print("services.json")
    let items = try decoder.decode([BrewServiceItem].self, from: fixture("services", "json"))
    check(items.count == 3, "解码出 3 个服务")

    let mysql = items.first { $0.name == "mysql" }
    check(mysql?.status == "stopped", "mysql stopped")
    check(mysql?.user == "yangkai", "mysql user")
    check(mysql?.exitCode == 0, "mysql exit_code=0")
    check(mysql?.isRunning == false, "mysql 未运行")

    let redis = items.first { $0.name == "redis" }
    check(redis?.isRunning == true, "redis 运行中")

    let colima = items.first { $0.name == "colima" }
    check(colima?.user == nil, "colima user 为 null")
    check(colima?.exitCode == nil, "colima exit_code 为 null")
} catch {
    check(false, "services.json 解码", error.localizedDescription)
}

// MARK: - 搜索输出解析(brew 6 裸名称列表)

do {
    print("parseNameList")
    let text = String(decoding: try fixture("search", "txt"), as: UTF8.self)
    let names = BrewService.parseNameList(text)
    check(names.count == 10, "解析出 10 个名称", "\(names.count)")
    check(names.contains("git-lfs"), "含 git-lfs")
    check(!names.contains(""), "无空行")

    let withNoise = "==> Formulae\nwget\n\nwget2\n"
    check(BrewService.parseNameList(withNoise) == ["wget", "wget2"], "忽略 ==> 标题与空行")
}

// MARK: - 防御性 JSON 提取

do {
    print("decodeAllowingPartial")
    var noisy = Data("✔︎ JSON API packages.json\n".utf8)
    noisy.append(try fixture("services", "json"))
    let items = try BrewService.decodeAllowingPartial(noisy, as: [BrewServiceItem].self)
    check(items?.count == 3, "跳过前导噪声行解码")

    let garbage = try BrewService.decodeAllowingPartial(Data("not json at all".utf8), as: [BrewServiceItem].self)
    check(garbage == nil, "纯垃圾输入返回 nil")
} catch {
    check(false, "decodeAllowingPartial", error.localizedDescription)
}

// MARK: - live 模式:对真实 brew 做冒烟验证(swift run SteinCoreChecks live)

if CommandLine.arguments.contains("live") {
    print("live: 对真实 brew 查询")
    let brew = BrewService()
    do {
        let packages = try await brew.installedPackages()
        let formulaeCount = packages.filter { $0.kind == .formula }.count
        let caskCount = packages.filter { $0.kind == .cask }.count
        print("  已安装:\(formulaeCount) formulae, \(caskCount) casks")

        let outdated = try await brew.outdated()
        print("  可更新:\(outdated.formulae.count) formulae, \(outdated.casks.count) casks")

        let services = try await brew.services()
        print("  服务:\(services.count) 个(\(services.filter(\.isRunning).count) 运行中)")

        let results = try await brew.search(term: "wget")
        print("  搜索 'wget':\(results.count) 个结果")

        check(formulaeCount > 0, "live: 已安装 formulae 非空")
        check(results.contains { $0.id == "wget" }, "live: 搜索能找到 wget")
    } catch {
        check(false, "live 查询", error.localizedDescription)
    }
}

print("\n\(passed) 通过, \(failures) 失败")
if failures > 0 { exit(1) }
print("All checks passed")
