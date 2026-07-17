import Foundation
import SteinCore

@MainActor
@Observable
final class InstalledViewModel {
    private let brew = BrewService()

    private(set) var packages: [BrewPackage] = []
    var isLoading = false

    var formulae: [BrewPackage] { packages.filter { $0.kind == .formula } }
    var casks: [BrewPackage] { packages.filter { $0.kind == .cask } }

    func load() async throws {
        isLoading = true
        defer { isLoading = false }
        packages = try await brew.installedPackages()
    }

    /// 供搜索页判断某个名字是否已安装。
    func isInstalled(_ id: String) -> Bool {
        packages.contains { $0.id == id }
    }
}
