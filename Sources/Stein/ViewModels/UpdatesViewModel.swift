import Foundation
import SteinCore

/// 过期列表条目:OutdatedEntry 加上类型信息。
struct OutdatedItem: Identifiable, Hashable {
    let kind: PackageKind
    let entry: OutdatedEntry

    var id: String { entry.id }
    var installed: String { entry.installedVersions.joined(separator: ", ") }
    var current: String { entry.currentVersion }
}

@MainActor
@Observable
final class UpdatesViewModel {
    private let brew = BrewService()

    private(set) var items: [OutdatedItem] = []
    var isLoading = false

    func refresh() async throws {
        isLoading = true
        defer { isLoading = false }
        let response = try await brew.outdated()
        items = response.formulae.map { OutdatedItem(kind: .formula, entry: $0) }
            + response.casks.map { OutdatedItem(kind: .cask, entry: $0) }
    }
}
