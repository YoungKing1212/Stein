import Foundation
import SteinCore

@MainActor
@Observable
final class SearchViewModel {
    private let brew = BrewService()

    var query = ""
    private(set) var results: [BrewPackage] = []
    private(set) var isSearching = false
    private(set) var hasSearched = false

    /// 由 .task(id: query) 驱动:自动去抖、自动取消过期搜索。
    func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            results = []
            hasSearched = false
            return
        }
        // 简单去抖:等待 400ms,期间任务被取消则直接退出。
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        do {
            results = try await brew.search(term: term)
            hasSearched = true
        } catch is CancellationError {
            // 搜索被新输入取消,忽略。
        } catch {
            results = []
            hasSearched = true
        }
    }
}
