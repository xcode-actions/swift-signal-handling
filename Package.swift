// swift-tools-version:5.3
import PackageDescription


let package = Package(
	name: "swift-signal-handling",
	platforms: [
		.macOS(.v10_15)
	],
	products: [
		.library(name: "SignalHandling", targets: ["SignalHandling"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
		.package(url: "https://github.com/apple/swift-system.git", from: "1.0.0"),
		.package(url: "https://github.com/swift-server/swift-backtrace.git", from: "1.3.1"),
		.package(url: "https://github.com/xcode-actions/clt-logger.git", from: "0.3.0")
	],
	targets: [
		.target(name: "SignalHandling", dependencies: [
			.product(name: "Logging", package: "swift-log"),
			.product(name: "SystemPackage", package: "swift-system")
		]),
		
		.target(name: "signal-handling-tests-helper", dependencies: [
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "Backtrace",      package: "swift-backtrace"),
			.product(name: "CLTLogger",      package: "clt-logger"),
			.product(name: "Logging",        package: "swift-log"),
			.target(name: "SignalHandling")
		]),
		.testTarget(name: "SignalHandlingTests", dependencies: [
			.target(name: "signal-handling-tests-helper"),
			.product(name: "CLTLogger",     package: "clt-logger"),
			.product(name: "Logging",       package: "swift-log"),
			.product(name: "SystemPackage", package: "swift-system")
		]),
	]
)
