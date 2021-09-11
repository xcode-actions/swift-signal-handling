import Foundation
import XCTest



final class NSConditionLockTest : XCTestCase {
	
	func testNSConditionLock() throws {
		/* Apparently XCTExpectFailure does not exist on Linux. */
//#if os(Linux)
//		XCTExpectFailure("Linux has a crash in NSConditionLock. This test is only here to remember to check if the bug is fixed from time to time (simply uncomment the second line of the test; if test does not crash on Linux we’re good).")
//#endif
		
		let p = Process()
		p.executableURL = Utils.helperURL
		p.arguments = ["condition-lock"]
		
		try p.run()
		
		Thread.sleep(forTimeInterval: 0.125) /* We wait a little bit to let the helper test have the time to crash */
		p.terminate()
		Thread.sleep(forTimeInterval: 0.125) /* We wait a little bit to let the helper test process the signal and quit */
		
		XCTAssertEqual(p.terminationStatus, 0)
		XCTAssertEqual(p.terminationReason, .exit)
	}
	
}
