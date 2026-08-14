// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FormsKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FormsKit",
            targets: ["FormsKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.9.5"),
        .package(url: "https://source.skip.tools/skip-fuse.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.

        .target(
            name: "FormsKit",
            dependencies: [
                .product(name: "SkipFuse", package: "skip-fuse"),
                // SkipFuseUI (not the SkipSwiftUI product): depending on the
                // dynamic SkipSwiftUI product alongside SkipFuseUI's static use
                // of the same target is a SwiftPM linkage conflict; the
                // SkipSwiftUI *module* is importable transitively.
                .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            ],
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        .testTarget(
            name: "FormsKitTests",
            dependencies: [
                "FormsKit",
                .product(name: "SkipTest", package: "skip"),
            ],
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
    ],
    swiftLanguageModes: [.v6]
)

// Setting the SKIP_ZERO=1 environment strips out the Skip plugin and all Skip dependencies,
// restoring FormsKit to a zero-dependency package for consumers that don't target Android.
if Context.environment["SKIP_ZERO"] ?? "0" != "0" {
    package.targets.forEach { target in
        // remove the Skip plugin
        target.plugins?.removeAll(where: {
            if case .plugin(let name, _) = $0 {
                return name == "skipstone"
            } else {
                return false
            }
        })

        // remove the Skip target dependencies
        target.dependencies.removeAll(where: { dependency in
            if case .productItem(_, let package, _, _) = dependency {
                return package == "skip" || package?.hasPrefix("skip-") == true
            } else {
                return false
            }
        })
    }

    // remove the Skip package dependencies
    package.dependencies.removeAll(where: { dependency in
        if case .sourceControl(_, let url, _) = dependency.kind {
            return url.hasPrefix("https://source.skip.dev/") || url.hasPrefix("https://source.skip.tools/")
        } else {
            return false
        }
    })
}
