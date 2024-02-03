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
		.watchOS(.v7)
	],
	products: [
		.library(name: "SignalHandling", targets: ["SignalHandling"])
	],
	dependencies: {
		var res = [Package.Dependency]()
		res.append(.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"))
		res.append(.package(url: "https://github.com/apple/swift-log.git",             from: "1.4.2"))
		res.append(.package(url: "https://github.com/xcode-actions/clt-logger.git",    from: "0.4.0"))
#if !canImport(System)
		res.append(.package(url: "https://github.com/apple/swift-system.git",          from: "1.0.0"))
#endif
		return res
	}(),
	targets: [
		.target(name: "SignalHandling", dependencies: {
			var res = [Target.Dependency]()
			res.append(.product(name: "Logging", package: "swift-log"))
#if !canImport(System)
			res.append(.product(name: "SystemPackage", package: "swift-system"))
#endif
			return res
		}(), swiftSettings: noSwiftSettings),
		
		.target(name: "signal-handling-tests-helper", dependencies: [
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "CLTLogger",      package: "clt-logger"),
			.product(name: "Logging",        package: "swift-log"),
			.target(name: "SignalHandling")
		], swiftSettings: noSwiftSettings),
		.testTarget(name: "SignalHandlingTests", dependencies: {
			var res = [Target.Dependency]()
			res.append(.target(name: "signal-handling-tests-helper"))
			res.append(.product(name: "CLTLogger",     package: "clt-logger"))
			res.append(.product(name: "Logging",       package: "swift-log"))
#if !canImport(System)
			res.append(.product(name: "SystemPackage", package: "swift-system"))
#endif
			return res
		}(), swiftSettings: noSwiftSettings)
	]
)
