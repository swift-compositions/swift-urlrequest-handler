// swift-tools-version: 6.3.3

import PackageDescription

let package = Package(
    name: "swift-urlrequest-handler",
    platforms: [
      .iOS("27"),
      .macOS("27"),
      .tvOS("27"),
      .watchOS("27")
    ],
    products: [
        .library(name: "URLRequestHandler", targets: ["URLRequestHandler"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-compositions/swift-dependencies.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-logger-dependencies.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "URLRequestHandler",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Logger Dependencies", package: "swift-logger-dependencies"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "URLRequestHandler Tests",
            dependencies: [
                .target(name: "URLRequestHandler"),
                .product(name: "Dependencies Test Support", package: "swift-dependencies")
            ]
        )
    ]
)

