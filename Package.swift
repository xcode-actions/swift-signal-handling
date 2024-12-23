// swift-tools-version:6.0
import PackageDescription


let swiftSettings: [SwiftSetting] = []

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
		.package(url: "https://github.com/Frizlab/GlobalConfModule.git",    from: "0.4.0"),
		.package(url: "https://github.com/xcode-actions/clt-logger.git",    from: "1.0.0-beta.4"),
	],
	targets: [
		.target(name: "SignalHandling", dependencies: [
			.product(name: "Logging",          package: "swift-log"),
			.product(name: "GlobalConfModule", package: "GlobalConfModule"),
		], swiftSettings: swiftSettings),
		
		.executableTarget(name: "signal-handling-tests-helper", dependencies: [
			.product(name: "ArgumentParser",   package: "swift-argument-parser"),
			.product(name: "CLTLogger",        package: "clt-logger"),
			.product(name: "GlobalConfModule", package: "GlobalConfModule"),
			.product(name: "Logging",          package: "swift-log"),
			.target(name: "SignalHandling"),
		], swiftSettings: swiftSettings),
		.testTarget(name: "SignalHandlingTests", dependencies: [
			.target(name: "signal-handling-tests-helper"),
			.product(name: "CLTLogger",        package: "clt-logger"),
			.product(name: "GlobalConfModule", package: "GlobalConfModule"),
			.product(name: "Logging",          package: "swift-log"),
		], swiftSettings: swiftSettings),
	]
)
