import Foundation

/// `brew services list --json` 的单条服务记录。
public struct BrewServiceItem: Codable, Identifiable, Hashable, Sendable {
    public let name: String
    /// started / stopped / error / none(未注册)、scheduled 等。
    public let status: String?
    public let user: String?
    public let file: String?
    public let exitCode: Int?

    public var id: String { name }
    public var isRunning: Bool { status == "started" }

    enum CodingKeys: String, CodingKey {
        case name, status, user, file
        case exitCode = "exit_code"
    }
}
