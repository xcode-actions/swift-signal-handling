import Foundation

import ArgumentParser
import CLTLogger
import Logging

import SignalHandling



struct ManualTest : ParsableCommand {
	
	static var logger: Logger?
	
	func run() throws {
//		try SigactionDelayer_Block.bootstrap(for: Signal.toForwardToSubprocesses)
		LoggingSystem.bootstrap{ _ in CLTLogger() }
		
		var logger = Logger(label: "main")
		logger.logLevel = .trace
		ManualTest.logger = logger /* We must do this to be able to use the logger from the C handler. */
		SignalHandlingConfig.logger?.logLevel = .trace
		
		try Sigaction(handler: .ansiC({ _ in ManualTest.logger?.debug("In libxct-test-helper sigaction handler for interrupt") })).install(on: .interrupt)
		try Sigaction(handler: .ansiC({ _ in ManualTest.logger?.debug("In libxct-test-helper sigaction handler for terminated") })).install(on: .terminated)
		
		let s = DispatchSource.makeSignalSource(signal: Signal.terminated.rawValue)
		s.setEventHandler(handler: { ManualTest.logger?.debug("In libxct-test-helper dispatch source handler for terminated") })
		s.activate()
		
		let delayedSignal = Signal.terminated
		_ = try SigactionDelayer_Unsig.registerDelayedSigaction(delayedSignal, handler: { _, doneHandler in
			DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500), execute: {
				logger.info("Allowing signal to be resent")
				doneHandler(true)
			})
		})
		
		sleep(1)
		logger.info("Sending signal \(delayedSignal) to myself")
		kill(getpid(), delayedSignal.rawValue)
		
		sleep(3)
	}
	
}
