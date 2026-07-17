import Foundation
import SteinCore

@MainActor
@Observable
final class ServicesViewModel {
    private let brew = BrewService()

    private(set) var items: [BrewServiceItem] = []
    var isLoading = false

    func refresh() async throws {
        isLoading = true
        defer { isLoading = false }
        items = try await brew.services()
    }
}
