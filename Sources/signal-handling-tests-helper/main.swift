import Foundation

import ArgumentParser



struct SignalHandlingTestsHelper : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		subcommands: [
			ManualTest.self
		]
	)
	
}

SignalHandlingTestsHelper.main()
