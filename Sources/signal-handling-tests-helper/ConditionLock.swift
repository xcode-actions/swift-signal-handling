import Foundation

import ArgumentParser

import SignalHandling



struct ConditionLock : ParsableCommand {
	
	func run() throws {
		/* The terminated signal is _not_ Ctrl-C… */
		try Sigaction(handler: .ansiC({ _ in ConditionLock.exit() })).install(on: .terminated)
		
		NSConditionLock(condition: 0).lock(whenCondition: 1)
	}
	
}
