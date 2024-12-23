import Foundation

import ArgumentParser
import CLTLogger
import Logging

import SignalHandling



struct DelaySignalUnsigaction : ParsableCommand {
	
	@Option
	var signalNumber: CInt
	
	func run() throws {
		LoggingSystem.bootstrap{ _ in CLTLogger(multilineMode: .allMultiline) }
		SignalHandlingConfig.logger?.logLevel = .trace
		
		let signal = Signal(rawValue: signalNumber)
		
		try Sigaction(handler: .ansiC({ _ in writeToStdout("in sigaction handler") })).install(on: signal)
		
		_ = try SigactionDelayer_Unsig.registerDelayedSigaction(signal, handler: { _, doneHandler in
			DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500), execute: {
				writeToStdout("allowing signal to be resent")
				doneHandler(true)
			})
		})
		
		Thread.sleep(until: .distantFuture)
	}
	
}

/* Using print does not work in Terminal probably due to buffering. */
private func writeToStdout(_ str: String) {
	try! FileHandle.standardOutput.write(contentsOf: Data((str + "\n").utf8))
}
