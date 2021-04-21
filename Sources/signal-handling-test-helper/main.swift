import Foundation

import ArgumentParser



struct LibxctTestHelper : ParsableCommand {
	
	static var configuration = CommandConfiguration(
		subcommands: [
			ManualTest.self
		]
	)
	
}

LibxctTestHelper.main()
