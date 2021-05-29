import Foundation

import ArgumentParser
import CLTLogger
import Logging
import SystemPackage

import SignalHandling



struct DelaySignalUnsigaction : ParsableCommand {
	
	@Option
	var signalNumber: CInt
	
	func run() throws {
//		try SigactionDelayer_Block.bootstrap(for: [Signal(rawValue: signalNumber)])
		LoggingSystem.bootstrap{ _ in CLTLogger() }
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
	try! FileDescriptor.standardOutput.writeAll(Data((str + "\n").utf8))
}
