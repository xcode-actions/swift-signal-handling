import Foundation
import XCTest

import CLTLogger
import GlobalConfModule
import Logging

@testable import SignalHandling



#if !os(tvOS) && !os(visionOS) && !os(iOS) && !os(watchOS)
final class SignalHandlingTests : XCTestCase {
	
	override class func setUp() {
		super.setUp()
		
		/* Setup the logger – Not needed for most tests as we launch an external executable to test. */
		LoggingSystem.bootstrap{ _ in CLTLogger(multilineMode: .allMultiline) }
		Conf[rootValueFor: \.signalHandling.logger]?.logLevel = .trace
	}
	
	/* Note:
	 * This test fails on Linux in non-release build
	 *  because the helper crashes
	 *  because it spawns a thread before we have a change to do the bootstrap required for the unsigaction
	 *  and we assert no threads has been created in the bootstrap.
	 * It also creates the thread(s) in release builds, but the asserts are skipped in release… */
	func testBasicSignalDelayByUnsigaction() throws {
		let pipe = Pipe()
		
		let p = Process()
		p.standardOutput = pipe
		p.executableURL = Utils.helperURL
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
		p.executableURL = Utils.helperURL
		p.arguments = ["delay-signal-block", "--signal-number", "\(Signal.terminated.rawValue)"]
		
		try p.run()
		
		Thread.sleep(forTimeInterval: 0.125) /* If we go too soon, the handler are not installed yet. */
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
	
}
#endif
