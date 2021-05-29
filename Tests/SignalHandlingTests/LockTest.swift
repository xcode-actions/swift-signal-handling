import Foundation
import XCTest



final class NSConditionLockTest : XCTestCase {
	
	func testNSConditionLock() throws {
//		Thread(block: { NSConditionLock(condition: 0).lock(whenCondition: 1) }).start()
		Thread.sleep(forTimeInterval: 0.1)
		
		#if !os(Linux)
		XCTAssert(true)
		#else
		XCTAssert(false, "This test crashes on Linux for now with Swift 5.4.1 (when the NSConditionLock line is uncommented); when it does not crash there will be something to do in the SwiftHandling code. So we fail the test to remember that.")
		#endif
	}
	
}
