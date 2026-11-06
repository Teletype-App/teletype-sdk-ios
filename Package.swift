// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TeletypeSDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(name: "TeletypeSDK", targets: ["TeletypeSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.1.1"),
    ],
    targets: [
        .target(
            name: "TeletypeSDK",
            dependencies: [
                .product(name: "SocketIO", package: "socket.io-client-swift"),
            ],
            path: "Sources/TeletypeSDK",
            resources: [
                .process("Resources"),
            ]
        ),
    ]
)
