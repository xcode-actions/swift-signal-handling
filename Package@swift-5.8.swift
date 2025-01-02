// swift-tools-version:5.8
import PackageDescription


let swiftSettings: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

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
		/* We’re aware of the existence of System on macOS. After some thinking/research, we decided to agree with <https://forums.swift.org/t/50719/5>.
		 * Basically what we want is optional dependencies, but they are not implemented (nor planned) in SPM for now <https://forums.swift.org/t/swiftpm-canimport/11749>.
		 * There are also cross-import overlays that exist (<https://sundayswift.com/posts/cross-import-overlays/>), but they are not possible to do with SPM (and are not what I really want here anyway). */
		.package(url: "https://github.com/apple/swift-system.git",          from: "1.0.0"),
		.package(url: "https://github.com/xcode-actions/clt-logger.git",    from: "1.0.0-beta.4"),
	],
	targets: [
		.target(name: "SignalHandling", dependencies: [
			.product(name: "Logging",       package: "swift-log"),
			.product(name: "SystemPackage", package: "swift-system"),
		], swiftSettings: swiftSettings),
		
		.executableTarget(name: "signal-handling-tests-helper", dependencies: [
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "CLTLogger",      package: "clt-logger"),
			.product(name: "Logging",        package: "swift-log"),
			.target(name: "SignalHandling"),
		], swiftSettings: swiftSettings),
		.testTarget(name: "SignalHandlingTests", dependencies: [
			.target(name: "signal-handling-tests-helper"),
			.product(name: "CLTLogger", package: "clt-logger"),
			.product(name: "Logging",   package: "swift-log"),
		], swiftSettings: swiftSettings),
	]
)
