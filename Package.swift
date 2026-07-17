// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stein",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "SteinCore"
        ),
        .executableTarget(
            name: "Stein",
            dependencies: ["SteinCore"]
        ),
        // 本机只有 Command Line Tools(无 XCTest / swift-testing),
        // 因此用零依赖的可执行检查器承担单元测试职责:`swift run SteinCoreChecks`。
        .executableTarget(
            name: "SteinCoreChecks",
            dependencies: ["SteinCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
