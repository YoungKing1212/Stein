import Foundation

// MARK: - brew info --json=v2 响应模型

/// `brew info --json=v2` 输出中的 formula 条目(只保留 UI 需要的字段,未知字段自动忽略)。
public struct Formula: Codable, Identifiable, Hashable {
    public let name: String
    public let fullName: String?
    public let tap: String?
    public let desc: String?
    public let license: String?
    public let homepage: String?
    public let versions: Versions?
    public let dependencies: [String]?
    public let caveats: String?
    public let installed: [InstalledVersion]?
    public let linkedKeg: String?
    public let pinned: Bool?
    public let outdated: Bool?
    public let kegOnly: Bool?
    public let deprecated: Bool?
    public let disabled: Bool?

    public var id: String { name }

    public struct Versions: Codable, Hashable {
        public let stable: String?
    }

    public struct InstalledVersion: Codable, Hashable {
        public let version: String
        public let installedOnRequest: Bool?

        enum CodingKeys: String, CodingKey {
            case version
            case installedOnRequest = "installed_on_request"
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, tap, desc, license, homepage, versions, dependencies, caveats
        case installed, pinned, outdated, deprecated, disabled
        case fullName = "full_name"
        case linkedKeg = "linked_keg"
        case kegOnly = "keg_only"
    }
}

/// `brew info --json=v2` 输出中的 cask 条目。
public struct Cask: Codable, Identifiable, Hashable {
    public let token: String
    public let name: [String]?
    public let desc: String?
    public let homepage: String?
    public let version: String?
    /// 已安装版本;未安装时为 null。注意 cask 的 installed 是字符串而非数组。
    public let installed: String?
    public let outdated: Bool?
    public let caveats: String?
    public let deprecated: Bool?

    public var id: String { token }
    public var displayName: String { name?.first ?? token }
}

public struct InstalledResponse: Codable {
    public let formulae: [Formula]
    public let casks: [Cask]
}

// MARK: - brew outdated --json=v2 响应模型

public struct OutdatedEntry: Codable, Identifiable, Hashable {
    public let name: String
    public let installedVersions: [String]
    public let currentVersion: String
    public let pinned: Bool?

    public var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, pinned
        case installedVersions = "installed_versions"
        case currentVersion = "current_version"
    }
}

public struct OutdatedResponse: Codable {
    public let formulae: [OutdatedEntry]
    public let casks: [OutdatedEntry]
}

// MARK: - 统一 UI 模型

public enum PackageKind: String, Hashable, Sendable {
    case formula = "Formula"
    case cask = "Cask"
}

/// 列表/详情统一使用的包模型,由 Formula / Cask 转换而来,并合并 outdated 信息。
public struct BrewPackage: Identifiable, Hashable, Sendable {
    public let kind: PackageKind
    /// formula 的 name 或 cask 的 token,即传给 brew 命令的标识。
    public let id: String
    public let displayName: String
    public let desc: String?
    public let homepage: String?
    public let installedVersion: String?
    public let latestVersion: String?
    public var isOutdated: Bool
    public let pinned: Bool
    public let installedOnRequest: Bool
    public let dependencies: [String]
    public let caveats: String?

    public var isInstalled: Bool { installedVersion != nil }

    public init(
        kind: PackageKind,
        id: String,
        displayName: String,
        desc: String?,
        homepage: String?,
        installedVersion: String?,
        latestVersion: String?,
        isOutdated: Bool,
        pinned: Bool,
        installedOnRequest: Bool,
        dependencies: [String],
        caveats: String?
    ) {
        self.kind = kind
        self.id = id
        self.displayName = displayName
        self.desc = desc
        self.homepage = homepage
        self.installedVersion = installedVersion
        self.latestVersion = latestVersion
        self.isOutdated = isOutdated
        self.pinned = pinned
        self.installedOnRequest = installedOnRequest
        self.dependencies = dependencies
        self.caveats = caveats
    }
}

public extension BrewPackage {
    init(formula: Formula, outdatedEntry: OutdatedEntry? = nil) {
        self.init(
            kind: .formula,
            id: formula.name,
            displayName: formula.name,
            desc: formula.desc,
            homepage: formula.homepage,
            installedVersion: formula.installed?.last?.version,
            latestVersion: outdatedEntry?.currentVersion ?? formula.versions?.stable,
            isOutdated: outdatedEntry != nil || (formula.outdated ?? false),
            pinned: formula.pinned ?? false,
            installedOnRequest: formula.installed?.last?.installedOnRequest ?? false,
            dependencies: formula.dependencies ?? [],
            caveats: formula.caveats
        )
    }

    init(cask: Cask, outdatedEntry: OutdatedEntry? = nil) {
        self.init(
            kind: .cask,
            id: cask.token,
            displayName: cask.displayName,
            desc: cask.desc,
            homepage: cask.homepage,
            installedVersion: cask.installed,
            latestVersion: outdatedEntry?.currentVersion ?? cask.version,
            isOutdated: outdatedEntry != nil || (cask.outdated ?? false),
            pinned: false,
            installedOnRequest: true, // cask 均为显式安装
            dependencies: [],
            caveats: cask.caveats
        )
    }
}
