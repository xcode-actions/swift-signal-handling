// swift-tools-version:5.3
import PackageDescription


/* ⚠️ Do not use the concurrency check flags in a release! */
let          noSwiftSettings: [SwiftSetting] = []
//let concurrencySwiftSettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]

let package = Package(
	name: "swift-signal-handling",
	platforms: [
		.macOS(.v11),
		.tvOS(.v14),
		.iOS(.v14),
		.watchOS(.v7),
	],
	products: [
		.library(name: "SignalHandling", targets: ["SignalHandling"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-log.git",             from: "1.4.2"),
		.package(url: "https://github.com/xcode-actions/clt-logger.git",    from: "1.0.0-beta"),
	],
	targets: [
		.target(name: "SignalHandling", dependencies: [
			.product(name: "Logging", package: "swift-log"),
		], swiftSettings: noSwiftSettings),
		
		.target(name: "signal-handling-tests-helper", dependencies: [
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "CLTLogger",      package: "clt-logger"),
			.product(name: "Logging",        package: "swift-log"),
			.target(name: "SignalHandling"),
		], swiftSettings: noSwiftSettings),
		.testTarget(name: "SignalHandlingTests", dependencies: [
			.target(name: "signal-handling-tests-helper"),
			.product(name: "CLTLogger",     package: "clt-logger"),
			.product(name: "Logging",       package: "swift-log"),
		], swiftSettings: noSwiftSettings)
	]
)
