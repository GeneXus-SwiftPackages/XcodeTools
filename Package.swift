// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let CMakeFiles = ["CMakeLists.txt"]

let package = Package(
    name: "XcodeTools",
	platforms: [.macOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
		.executable(name: "RunTests", targets: ["RunTests"]),
		.executable(name: "ExtractTestResults", targets: ["ExtractTestResults"]),
		.plugin(name: "RunGXTests", targets: ["RunGXTests"])
    ],
	dependencies: [
		.package(url: "https://github.com/apple/swift-tools-support-core.git", .upToNextMajor(from: "0.3.0")),
		.package(url: "https://github.com/ChargePoint/xcparse.git", .upToNextMajor(from: "2.3.1")),
		.package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "1.2.0")),
		.package(url: "https://github.com/happn-app/CollectionConcurrencyKit.git", revision: "b2b4dc4b363cf4301586f75d24b9ffe17111a286")
	],
    targets: [
		// MARK: Public targets
		
		.executableTarget(
            name: "RunTests",
			dependencies: [
				.target(name: "CommonHelpers"),
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
			]
		),
		
		.executableTarget(name: "ExtractTestResults",
						  dependencies: [
							.target(name: "CommonHelpers"),
							.product(name: "ArgumentParser", package: "swift-argument-parser"),
							.product(name: "XCParseCore", package: "xcparse"),
							.product(name: "CollectionConcurrencyKit", package: "CollectionConcurrencyKit")
						  ]),
		
		// MARK: Plugin targets
		
		.plugin(name: "RunGXTests",
				capability: .command(intent: .custom(verb: "run-gxtests", description: "Run and extract results from GX Tests in project")),
			   dependencies: [
				.target(name: "RunTests"),
				.target(name: "ExtractTestResults")
			   ]),
		
		// MARK: Helper targets
		
		.target(name: "CommonHelpers",
				dependencies: [
					.product(name: "TSCBasic", package: "swift-tools-support-core"),
					.product(name: "ArgumentParser", package: "swift-argument-parser"),
			   ]
		),
		
		// MARK: Test targets
		
        .testTarget(
            name: "RunTestsTests",
            dependencies: ["RunTests"]),
    ]
)
