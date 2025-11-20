import Foundation

import ArgumentParser
import CLTLogger
import GlobalConfModule
import Logging

import SignalHandling



struct DropSignalUnsigaction : ParsableCommand {
	
	@Option
	var signalNumber: CInt
	
	func run() throws {
		LoggingSystem.bootstrap{ _ in CLTLogger(multilineMode: .allMultiline) }
		Conf[rootValueFor: \.signalHandling.logger]?.logLevel = .trace
		
		let signal = Signal(rawValue: signalNumber)
		
		_ = try SigactionDelayer_Unsig.registerDelayedSigaction(signal, handler: { _, doneHandler in
			writeToStdout("dropping signal")
			doneHandler(false)
		})
		
		Thread.sleep(until: .distantFuture)
	}
	
}

/* Using print does not work in Terminal probably due to buffering. */
private func writeToStdout(_ str: String) {
	try! FileHandle.standardOutput.write(contentsOf: Data((str + "\n").utf8))
}
