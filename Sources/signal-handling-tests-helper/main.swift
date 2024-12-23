import Foundation

import ArgumentParser



struct SignalHandlingTestsHelper : ParsableCommand {
	
	static let configuration = CommandConfiguration(
		subcommands: [
			ManualTest.self,
			ManualDispatchMemTest.self,
			
			DelaySignalBlock.self,
			DelaySignalUnsigaction.self,
			
			ConditionLock.self
		]
	)
	
}

SignalHandlingTestsHelper.main()
