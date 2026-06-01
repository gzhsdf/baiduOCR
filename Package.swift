// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BaiduOCR",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "BaiduOCR",
            path: "Sources/BaiduOCR"
        )
    ]
)
