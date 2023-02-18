// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeStats",
    products: [
        .plugin(name: "GenerateCodeStats", targets: ["GenerateCodeStats"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SPMPluginSample",
            dependencies: []),
        .testTarget(
            name: "SPMPluginSampleTests",
            dependencies: ["SPMPluginSample"]),
        .plugin(
            name: "GenerateCodeStats",
            capability: .command(
                intent: .custom(
                    verb: "code-stats",
                    description: "Generates code statistics"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Generate code statistics file at root level")
                ]
            )
        )
    ]
)
