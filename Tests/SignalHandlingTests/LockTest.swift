import Foundation
import XCTest



final class NSConditionLockTest : XCTestCase {
	
	func testNSConditionLock() throws {
		/* https://bugs.swift.org/browse/SR-14676 */
//		Thread(block: { NSConditionLock(condition: 0).lock(whenCondition: 1) }).start()
		Thread.sleep(forTimeInterval: 0.1)
		
		#if !os(Linux)
		XCTAssert(true)
		#else
		/* Apparently XCTExpectFailure does not exist on Linux. */
//		XCTExpectFailure("Linux has a crash in NSConditionLock. This test is only here to remember to check if the bug is fixed from time to time (simply uncomment the second line of the test; if test does not crash on Linux we’re good).")
		XCTAssert(false, "Linux has a crash in NSConditionLock. This test is only here to remember to check if the bug is fixed from time to time (simply uncomment the second line of the test; if test does not crash on Linux we’re good).")
		#endif
	}
	
}
