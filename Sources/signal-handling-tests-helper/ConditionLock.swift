import Foundation

import ArgumentParser

import SignalHandling



struct ConditionLock : ParsableCommand {
	
	func run() throws {
		try Sigaction(handler: .ansiC({ _ in ConditionLock.exit() })).install(on: .terminated)
		
		NSConditionLock(condition: 0).lock(whenCondition: 1)
	}
	
}
