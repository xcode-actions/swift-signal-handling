import Foundation

import ArgumentParser
import CLTLogger
import GlobalConfModule
import Logging

import SignalHandling



struct ManualTest : ParsableCommand {
	
	/* Only modified when the program starts. */
	static nonisolated(unsafe) var unsafeLogger: Logger?
	
	enum DelayMode : String, ExpressibleByArgument {
		case unsig
		case block
	}
	
	@Option
	var mode: DelayMode = .unsig
	
	func run() throws {
		if mode == .block {
			try SigactionDelayer_Block.bootstrap(for: Signal.toForwardToSubprocesses)
		}
		
		LoggingSystem.bootstrap{ _ in CLTLogger(multilineMode: .allMultiline) }
		
		var logger = Logger(label: "main")
		logger.logLevel = .trace
		Self.unsafeLogger = logger /* We must do this to be able to use the logger from the C handler. */
		Conf[rootValueFor: \.signalHandling.logger]?.logLevel = .trace
		
		try Sigaction(handler: .ansiC({ _ in Self.unsafeLogger?.debug("In libxct-test-helper sigaction handler for interrupt") })).install(on: .interrupt)
		try Sigaction(handler: .ansiC({ _ in Self.unsafeLogger?.debug("In libxct-test-helper sigaction handler for terminated") })).install(on: .terminated)
		
		let s = DispatchSource.makeSignalSource(signal: Signal.terminated.rawValue)
		s.setEventHandler(handler: { Self.unsafeLogger?.debug("In libxct-test-helper dispatch source handler for terminated") })
		s.activate()
		
		let delayedSignal = Signal.terminated
		let handler: DelayedSigactionHandler = { _, doneHandler in
			DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500), execute: { [logger] in
				logger.info("Allowing signal to be resent")
				doneHandler(true)
			})
		}
		switch mode {
			case .unsig: _ = try SigactionDelayer_Unsig.registerDelayedSigaction(delayedSignal, handler: handler)
			case .block: _ = try SigactionDelayer_Block.registerDelayedSigaction(delayedSignal, handler: handler)
		}
		
		
		sleep(1)
		logger.info("Sending signal \(delayedSignal) to myself (1st time)")
		kill(getpid(), delayedSignal.rawValue)
		
		sleep(1)
		logger.info("Sending signal \(delayedSignal) to myself (2nd time)")
		kill(getpid(), delayedSignal.rawValue)
		
		sleep(3)
	}
	
}
