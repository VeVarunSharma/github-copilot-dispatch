// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CopilotDispatch",
    platforms: [.watchOS(.v11)],
    targets: [
        .executableTarget(
            name: "CopilotDispatch",
            path: "Sources"
        )
    ]
)
