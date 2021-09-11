import Foundation



enum Utils {
	
	static let helperURL = productsDirectory.appendingPathComponent("signal-handling-tests-helper")
	
	/** Returns the path to the built products directory. */
	private static var productsDirectory: URL {
#if os(macOS)
		for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
			return bundle.bundleURL.deletingLastPathComponent()
		}
		fatalError("couldn't find the products directory")
#else
		return Bundle.main.bundleURL
#endif
	}
	
}
