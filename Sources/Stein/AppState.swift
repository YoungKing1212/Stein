import Foundation
import SteinCore

/// 应用级状态:聚合各分区 ViewModel 与命令中心,负责跨分区的刷新协调。
@MainActor
@Observable
final class AppState {
    let commandCenter = CommandCenter()
    let installed = InstalledViewModel()
    let updates = UpdatesViewModel()
    let services = ServicesViewModel()
    let search = SearchViewModel()

    /// 全局错误信息,以横幅形式展示。
    var errorMessage: String?

    func initialLoad() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadInstalled() }
            group.addTask { await self.refreshUpdates() }
            group.addTask { await self.refreshServices() }
        }
    }

    func loadInstalled() async {
        do {
            try await installed.load()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshUpdates() async {
        do {
            try await updates.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshServices() async {
        do {
            try await services.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 写操作完成后的统一刷新:已安装列表、过期列表、服务状态都可能变化。
    func refreshAfterMutation() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadInstalled() }
            group.addTask { await self.refreshUpdates() }
            group.addTask { await self.refreshServices() }
        }
    }

    // MARK: - 写操作(统一经 CommandCenter 执行,完成后刷新)

    func install(_ package: BrewPackage) async {
        let args = package.kind == .cask ? ["install", "--cask", package.id] : ["install", package.id]
        if await commandCenter.run(args) {
            await refreshAfterMutation()
        }
    }

    func uninstall(_ package: BrewPackage) async {
        let args = package.kind == .cask ? ["uninstall", "--cask", package.id] : ["uninstall", package.id]
        if await commandCenter.run(args) {
            await refreshAfterMutation()
        }
    }

    func upgrade(name: String) async {
        if await commandCenter.run(["upgrade", name]) {
            await refreshAfterMutation()
        }
    }

    func upgradeAll() async {
        if await commandCenter.run(["upgrade"]) {
            await refreshAfterMutation()
        }
    }

    /// 刷新 brew 元数据(brew update),然后重新检查 outdated。
    func updateMetadata() async {
        if await commandCenter.run(["update"]) {
            await refreshUpdates()
        }
    }

    /// action: start / stop / restart
    func performService(_ action: String, on name: String) async {
        if await commandCenter.run(["services", action, name]) {
            await refreshServices()
        }
    }
}
