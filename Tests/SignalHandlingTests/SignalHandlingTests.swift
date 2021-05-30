import Foundation
import XCTest

import CLTLogger
import Logging

@testable import SignalHandling



@available(OSX 10.15.4, *)
final class SignalHandlingTests : XCTestCase {
	
	static let helperURL = productsDirectory.appendingPathComponent("signal-handling-tests-helper")
	
	override class func setUp() {
		super.setUp()
		
		/* Setup the logger – Not needed for most tests as we launch an external
		 * executable to test. */
		LoggingSystem.bootstrap{ _ in CLTLogger() }
		SignalHandlingConfig.logger?.logLevel = .trace
	}
	
	func testBasicSignalDelayByUnsigaction() throws {
		let pipe = Pipe()
		
		let p = Process()
		p.standardOutput = pipe
		p.executableURL = Self.helperURL
		p.arguments = ["delay-signal-unsigaction", "--signal-number", "\(Signal.terminated.rawValue)"]
		
		try p.run()
		
		Thread.sleep(forTimeInterval: 0.125) /* If we go too soon, the handler are not installed yet */
		kill(p.processIdentifier, Signal.terminated.rawValue)
		
		Thread.sleep(forTimeInterval: 0.750)
		kill(p.processIdentifier, Signal.interrupt.rawValue)
		
		let data = try pipe.fileHandleForReading.readToEnd()
		p.waitUntilExit()
		
		XCTAssertEqual(data, Data("""
			allowing signal to be resent
			in sigaction handler
			
			""".utf8))
	}
	
	func testBasicSignalDelayByBlock() throws {
		let pipe = Pipe()
		
		let p = Process()
		p.standardOutput = pipe
		p.executableURL = Self.helperURL
		p.arguments = ["delay-signal-block", "--signal-number", "\(Signal.terminated.rawValue)"]
		
		try p.run()
		
		Thread.sleep(forTimeInterval: 0.125) /* If we go too soon, the handler are not installed yet */
		kill(p.processIdentifier, Signal.terminated.rawValue)
		
		Thread.sleep(forTimeInterval: 0.750)
		kill(p.processIdentifier, Signal.interrupt.rawValue)
		
		let data = try pipe.fileHandleForReading.readToEnd()
		p.waitUntilExit()
		
		XCTAssertEqual(data, Data("""
			allowing signal to be resent
			in sigaction handler
			
			""".utf8))
	}
	
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
