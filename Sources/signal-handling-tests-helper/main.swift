import Foundation

import ArgumentParser
import Backtrace



struct SignalHandlingTestsHelper : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		subcommands: [
			ManualTest.self,
			DelaySignalUnsigaction.self
		]
	)
	
}

//Backtrace.install()
SignalHandlingTestsHelper.main()
