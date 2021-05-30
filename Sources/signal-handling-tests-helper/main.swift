import Foundation

import ArgumentParser
import Backtrace



struct SignalHandlingTestsHelper : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		subcommands: [
			ManualTest.self,
			ManualDispatchMemTest.self,
			
			DelaySignalBlock.self,
			DelaySignalUnsigaction.self,
			
			ConditionLock.self
		]
	)
	
}

//Backtrace.install()
SignalHandlingTestsHelper.main()
