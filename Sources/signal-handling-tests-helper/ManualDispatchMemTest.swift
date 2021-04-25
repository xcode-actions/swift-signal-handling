import Foundation

import ArgumentParser
import CLTLogger
import Logging

import SignalHandling



private class MemWitness {
	
	func doNothingButKeepRefToWitness() {
	}
	
	deinit {
		ManualDispatchMemTest.logger?.debug("Deinit memory witness")
	}
	
}

struct ManualDispatchMemTest : ParsableCommand {
	
	static var logger: Logger?
	
	func run() throws {
		LoggingSystem.bootstrap{ _ in CLTLogger() }
		
		var logger = Logger(label: "main")
		logger.logLevel = .trace
		Self.logger = logger /* We must do this to be able to use the logger from the C handler. */
		SignalHandlingConfig.logger?.logLevel = .trace
		
		let signal = Signal.interrupt
		logger.info("Process started; monitored signal is \(signal)")
		
		try Sigaction(handler: .ansiC({ _ in Self.logger?.debug("In sigaction handler") })).install(on: signal)
		
		let memWitness = MemWitness()
		let s = DispatchSource.makeSignalSource(signal: signal.rawValue)
		s.setEventHandler{
			memWitness.doNothingButKeepRefToWitness()
			logger.debug("In dispatch source handler handler")
		}
		s.activate()
		
		sleep(1)
		logger.info("Sending signal \(signal) to myself")
		kill(getpid(), signal.rawValue)
		
		sleep(1)
		logger.info("Cancelling dispatch source")
		s.cancel()
		
		logger.info("Sleep before goodbye")
		sleep(1)
	}
	
}
