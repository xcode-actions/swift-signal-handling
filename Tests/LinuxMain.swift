import XCTest

@testable import SignalHandlingTests

var tests: [XCTestCaseEntry] = [
	testCase([
		("testNSConditionLock", NSConditionLockTest.testNSConditionLock),
	]),
	testCase([
		("testBasicSignalDelayByUnsigaction", SignalHandlingTests.testBasicSignalDelayByUnsigaction),
		("testBasicSignalDelayByBlock", SignalHandlingTests.testBasicSignalDelayByBlock),
	]),
]
XCTMain(tests)
