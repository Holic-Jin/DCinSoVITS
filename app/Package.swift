// swift-tools-version:5.9
// DCinSoVITS — Made by HolicJin
import PackageDescription

let package = Package(
    name: "DCinSoVITS",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DCinSoVITS",
            path: "Sources/DCinSoVITS",
            swiftSettings: [.unsafeFlags(["-Osize"])]
        )
    ]
)
