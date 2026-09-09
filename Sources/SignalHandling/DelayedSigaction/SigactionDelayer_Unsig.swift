import Foundation

import Logging
import SystemPackage



public enum SigactionDelayer_Unsig {
	
	/**
	 Will force the current signal to be ignored from the sigaction PoV, and handle the signal using a `DispatchSourceSignal`.
	 
	 This is useful to use a `DispatchSourceSignal`, because GCD will not change the sigaction when creating the source,
	  and thus, the sigaction _will be executed_ even if a dispatch source signal is setup for the given signal.
	 
	 __Example__: If you register a dispatch source signal for the signal 15 but does not ensure signal 15 is ignored,
	  when you receive this signal your program will stop because the default handler for this signal is to quit.
	 
	 All unsigaction IDs must be released for the original sigaction to be set on the signal again.
	 
	 - Note: On Linux, the `DispatchSourceSignal` does change the `sigaction` for the signal:
	  [libdispatch PR](https://github.com/apple/swift-corelibs-libdispatch/pull/560).
	 That’s one more reason to unsigaction the signal before handling it with GCD. */
	public static func registerDelayedSigaction(_ signal: Signal, handler: @escaping DelayedSigactionHandler) throws -> DelayedSigaction {
		return try signalProcessingQueue.sync{
			try registerDelayedSigactionOnQueue(signal, handler: handler)
		}
	}
	
	/**
	 Do **NOT** call this from the `handler` you give when unsigactioning a signal. */
	public static func unregisterDelayedSigaction(_ id: DelayedSigaction) throws {
		try signalProcessingQueue.sync{
			try unregisterDelayedSigactionOnQueue(id)
		}
	}
	
	/**
	 Convenience to register a delayed sigaction on multiple signals with the same handler in one function call.
	 
	 If a delay cannot be registered on one of the signal, the other signals that were successfully registered will be unregistered.
	 Of course this can fail too, in which case an error will be logged (but nothing more will be done). */
	public static func registerDelayedSigactions(_ signals: Set<Signal>, handler: @escaping DelayedSigactionHandler) throws -> [Signal: DelayedSigaction] {
		return try signalProcessingQueue.sync{
			var ret = [Signal: DelayedSigaction]()
			for signal in signals {
				do {
					ret[signal] = try registerDelayedSigactionOnQueue(signal, handler: handler)
				} catch {
					for (signal, UnsigactionID) in ret {
						do    {try unregisterDelayedSigactionOnQueue(UnsigactionID)}
						catch {SignalHandlingConfig.logger?.error(
							"Cannot unregister delayed sigaction for in recovery handler of registerDelayedSigactions. The signal will stay blocked, probably forever.",
							metadata: ["signal": "\(signal)", "error": "\(error)"]
						)}
					}
					throw error
				}
			}
			return ret
		}
	}
	
	/**
	 Convenience to unregister a set of delayed sigactions in one function call.
	 
	 All of the delayed sigaction will be attempted to be unregistered.
	 Errors will be returned.
	 The function is successful if the returned dictionary is empty. */
	public static func unregisterDelayedSigactions(_ delayedSigactions: Set<DelayedSigaction>) -> [Signal: Error] {
		return signalProcessingQueue.sync{
			var ret = [Signal: Error]()
			for delayedSigaction in delayedSigactions {
				do    {try Self.unregisterDelayedSigactionOnQueue(delayedSigaction)}
				catch {ret[delayedSigaction.signal] = error}
			}
			return ret
		}
	}
	
	/**
	 Change the original sigaction of the given signal if it was registered for an unsigaction.
	 This is useful if you want to change the sigaction handler after having registered an unsigaction.
	 
	 - Returns: The previous sigaction if there was an unsigaction registered for the given signal, `nil` otherwise. */
	public static func updateOriginalSigaction(for signal: Signal, to sigaction: Sigaction) -> Sigaction? {
		return signalProcessingQueue.sync{
			let previous = unsigactionedSignals[signal]?.originalSigaction
			unsigactionedSignals[signal]?.originalSigaction = sigaction
			return previous
		}
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum ThreadSync : Int {
		
		enum Action {
			case nop
			case send(Signal, with: Sigaction)
			case endThread /* Not actually used, but implemented. Would be useful in an unboostrap method. */
			
			var isNop: Bool {
				if case .nop = self {return true}
				return false
			}
		}
		
		struct ErrorAndLogs {
			
			var error: Error?
			/* These are non-fatal errors that should be logged. */
			var errorLogs: [(Logger.Message, Logger.Metadata?)]
			
			func logLogsAndThrowError() throws {
				for (log, metadata) in errorLogs {
					SignalHandlingConfig.logger?.error(log, metadata: metadata)
				}
				if let e = error {
					throw e
				}
			}
			
		}
		
		static let lock = NSConditionLock(condition: Self.nothingToDo.rawValue)
		
		static var action: Action = .nop
		static var completionResult: ErrorAndLogs?
		
		case nothingToDo
		case actionInThread
		case waitActionCompletion
		
	}
	
	private struct UnsigactionedSignal {
		
		var originalSigaction: Sigaction
		
		var dispatchSource: DispatchSourceSignal
		var handlers = [DelayedSigaction: DelayedSigactionHandler]()
		
	}
	
	private static let signalProcessingQueue = DispatchQueue(label: "com.xcode-actions.unsigactioned-signals-processing-queue")
	
	private static var hasCreatedProcessingThread = false
	private static var unsigactionedSignals = [Signal: UnsigactionedSignal]()
	
	private static func executeOnThread(_ action: ThreadSync.Action) throws {
		try createProcessingThreadIfNeededOnQueue()
		
		do {
#if !os(Linux)
			ThreadSync.lock.lock(whenCondition: ThreadSync.nothingToDo.rawValue)
#else
			/* Locking before a date too far in the future crashes on Linux.
			 * https://bugs.swift.org/browse/SR-14676 */
			while !ThreadSync.lock.lock(whenCondition: ThreadSync.nothingToDo.rawValue, before: Date(timeIntervalSinceNow: 24*60*60)) {}
#endif
			defer {ThreadSync.lock.unlock(withCondition: ThreadSync.actionInThread.rawValue)}
			assert(ThreadSync.completionResult == nil, "non-nil completionResult but acquired lock in nothingToDo state.")
			assert(ThreadSync.action.isNop, "non-nop action but acquired lock in nothingToDo state.")
			ThreadSync.action = action
		}
		
		do {
#if !os(Linux)
			ThreadSync.lock.lock(whenCondition: ThreadSync.waitActionCompletion.rawValue)
#else
			/* Locking before a date too far in the future crashes on Linux.
			 * https://bugs.swift.org/browse/SR-14676 */
			while !ThreadSync.lock.lock(whenCondition: ThreadSync.waitActionCompletion.rawValue, before: Date(timeIntervalSinceNow: 24*60*60)) {}
#endif
			defer {
				ThreadSync.completionResult = nil
				ThreadSync.lock.unlock(withCondition: ThreadSync.nothingToDo.rawValue)
			}
			assert(ThreadSync.action.isNop, "non-nop action but acquired lock in waitActionCompletion state.")
			let result = ThreadSync.completionResult! /* !-check: same as assert on line above. */
			try result.logLogsAndThrowError()
		}
	}
	
	/** Must always be called on the `signalProcessingQueue`. */
	private static func registerDelayedSigactionOnQueue(_ signal: Signal, handler: @escaping DelayedSigactionHandler) throws -> DelayedSigaction {
		/* Whether the signal was retained before or not, we re-install the ignore handler on the given signal. */
		let oldSigaction = try Sigaction.ignoreAction.install(on: signal, revertIfIgnored: false, updateUnsigRegistrations: false)
		
		let delayedSigaction = DelayedSigaction(signal: signal)
		
		var unsigactionedSignal: UnsigactionedSignal
		if let us = unsigactionedSignals[signal] {
			unsigactionedSignal = us
			if let oldSigaction = oldSigaction {
				/* The sigaction has been modified by someone else.
				 * We update our original sigaction to the new sigaction.
				 * Clients should not do that though. */
				unsigactionedSignal.originalSigaction = oldSigaction
				SignalHandlingConfig.logger?.warning("sigaction handler modified for an unsigactioned signal; the sigaction has been reset to ignore.", metadata: ["signal": "\(signal)"])
			}
		} else {
			let dispatchSourceSignal = DispatchSource.makeSignalSource(signal: signal.rawValue, queue: signalProcessingQueue)
			/* Apparently the dispatchSourceSignal does not need to be weak in the handler because the handler is released when the source is canceled.
			 * I manually tested this and found no confirmation or infirmation of this in the documentation. */
			dispatchSourceSignal.setEventHandler{ processSignalsOnQueue(signal: signal, count: dispatchSourceSignal.data) }
			dispatchSourceSignal.activate()
			
			unsigactionedSignal = UnsigactionedSignal(originalSigaction: oldSigaction ?? .ignoreAction, dispatchSource: dispatchSourceSignal)
		}
		
		assert(unsigactionedSignal.handlers[delayedSigaction] == nil)
		unsigactionedSignal.handlers[delayedSigaction] = handler
		unsigactionedSignals[signal] = unsigactionedSignal
		
		return delayedSigaction
	}
	
	/** Must always be called on the `signalProcessingQueue`. */
	private static func unregisterDelayedSigactionOnQueue(_ id: DelayedSigaction) throws {
		guard var unsigactionedSignal = unsigactionedSignals[id.signal] else {
			/* We trust our source not to have an internal logic error.
			 * If the unsigactioned signal is not found, it is because the callee called release twice on the same unsigaction ID. */
			SignalHandlingConfig.logger?.error("Overrelease of unsigation.", metadata: ["signal": "\(id.signal)"])
			return
		}
		assert(!unsigactionedSignal.handlers.isEmpty, "INTERNAL ERROR: unsigactionInfo should never be empty because when it is, the whole unsigactioned signal should be removed.")
		
		guard unsigactionedSignal.handlers.removeValue(forKey: id) != nil else {
			/* Same here.
			 * If the unsigaction ID was not in the unsigactionInfo, it can only be because the callee called release twice on the same ID. */
			SignalHandlingConfig.logger?.error("Overrelease of unsigation for signal", metadata: ["signal": "\(id.signal)"])
			return
		}
		
		if !unsigactionedSignal.handlers.isEmpty {
			/* We have nothing more to do except update the unsigactioned signals:
			 *  there are more unsigaction(s) that have been registered for this signal,
			 *  so we cannot touch the sigaction handler. */
			unsigactionedSignals[id.signal] = unsigactionedSignal
			return
		}
		
		/* Now we have removed **all** unsigactions on the given signal.
		 * Let’s restore the signal to the state before unsigactions. */
		try unsigactionedSignal.originalSigaction.install(on: id.signal, revertIfIgnored: false, updateUnsigRegistrations: false)
		unsigactionedSignal.dispatchSource.cancel()
		
		/* Finally, once the sigaction has been restored to the original value, we can remove the unsigactioned signal from the list. */
		unsigactionedSignals.removeValue(forKey: id.signal)
	}
	
	/** Must always be called on the `signalProcessingQueue`. */
	private static func processSignalsOnQueue(signal: Signal, count: UInt) {
		SignalHandlingConfig.logger?.debug("Processing signals, called from libdispatch.", metadata: ["signal": "\(signal)", "count": "\(count)"])
		
		/* Get the original sigaction for the given signal. */
		guard let unsigactionedSignal = unsigactionedSignals[signal] else {
			SignalHandlingConfig.logger?.error("INTERNAL ERROR: nil unsigactioned signal.", metadata: ["signal": "\(signal)"])
			return
		}
		SignalHandlingConfig.logger?.trace("", metadata: ["signal": "\(signal)", "original-sigaction": "\(unsigactionedSignal.originalSigaction)"])
		
		for _ in 0..<count {
			let group = DispatchGroup()
			var runOriginalHandlerFinal = true
			for (_, handler) in unsigactionedSignal.handlers {
				group.enter()
				handler(signal, { runOriginalHandler in
					runOriginalHandlerFinal = runOriginalHandlerFinal && runOriginalHandler
					group.leave()
				})
			}
			group.wait()
			if runOriginalHandlerFinal {
				SignalHandlingConfig.logger?.trace("Resending signal.", metadata: ["signal": "\(signal)"])
				do    {try executeOnThread(.send(signal, with: unsigactionedSignal.originalSigaction))}
				catch {SignalHandlingConfig.logger?.error("Error while resending signal in thread.", metadata: ["signal": "\(signal)", "error": "\(error)"])}
			} else {
				SignalHandlingConfig.logger?.trace("Signal resend skipped.", metadata: ["signal": "\(signal)"])
			}
		}
	}
	
	/** Must always be called on the `signalProcessingQueue`. */
	private static func createProcessingThreadIfNeededOnQueue() throws {
		guard !hasCreatedProcessingThread else {return}
		
		var error: Error?
		let group = DispatchGroup()
		group.enter()
		Thread.detachNewThread{
			Thread.current.name = "com.xcode-actions.unsigactioned-signals-thread"
			
			/* Unblock all signals in this thread. */
			var noSignals = Signal.emptySigset
			let ret = pthread_sigmask(SIG_SETMASK, &noSignals, nil /* old signals */)
			if ret != 0 {
				error = SignalHandlingError.destructiveSystemError(Errno(rawValue: ret))
			}
			group.leave()
			
			if ret == 0 {
				unsigactionedSignalsThreadLoop()
			}
		}
		
		group.wait()
		if let e = error {throw e}
		else             {hasCreatedProcessingThread = true}
	}
	
	private static func unsigactionedSignalsThreadLoop() {
		/* We process all the signals. */
		var emptyMask = Signal.emptySigset
		
		runLoop: repeat {
//			loggerLessThreadSafeDebugLog("🧵 New unsigactioned signals thread loop…")
		
#if !os(Linux)
			ThreadSync.lock.lock(whenCondition: ThreadSync.actionInThread.rawValue)
#else
			/* Locking before a date too far in the future crashes on Linux.
			 * https://bugs.swift.org/browse/SR-14676 */
			while !ThreadSync.lock.lock(whenCondition: ThreadSync.actionInThread.rawValue, before: Date(timeIntervalSinceNow: 24*60*60)) {}
#endif
			defer {
				ThreadSync.action = .nop
				ThreadSync.lock.unlock(withCondition: ThreadSync.waitActionCompletion.rawValue)
			}
			
			assert(ThreadSync.completionResult == nil, "non-nil error but acquired lock in actionInThread state.")
			var completionResult = ThreadSync.ErrorAndLogs(error: nil, errorLogs: [])
			defer {ThreadSync.completionResult = completionResult}
			
			do {
				switch ThreadSync.action {
					case .nop:
						(/*nop*/)
//						loggerLessThreadSafeDebugLog("🧵 Processing nop action…")
						assertionFailure("nop action while being locked w/ action in thread.")
						
					case .endThread:
//						loggerLessThreadSafeDebugLog("🧵 Processing endThread action…")
						break runLoop
						
					case .send(let signal, with: let sigaction):
//						loggerLessThreadSafeDebugLog("🧵 Processing send signal for \(signal) with \(sigaction)…")
						/* Install the original sigaction temporarily.
						 * In case of failure we do not even send the signal to ourselves, it’d be useless. */
						let previousSigaction = try sigaction.install(on: signal, revertIfIgnored: false, updateUnsigRegistrations: false)
						
						/* We send the signal to the thread directly.
						 * libdispatch uses kqueue (on BSD, signalfd on Linux) and thus signals sent to threads are not caught.
						 * Seems mostly true on Linux, but might require some tweaking.
						 * These signals are not caught by libdispatch… but signals are process-wide!
						 * And the sigaction is still executed.
						 * So we can reset the sigaction to the original value,
						 *  send the signal to the thread,
						 *  and set it back to ignore after that.
						 * The original signal handler will be executed.
						 *
						 * Both methods (raise and pthread_kill) work for raising the signal w/o being caught by libdispatch.
						 * pthread_kill might be safer, because it should really not be caught by libdispatch, while raise might
						 *  (it should not either, but it is less clear; IIUC in a multithreaded env it should never be caught though).
						 * Anyway, we need to reinstall the sigaction handler after the signal has been sent and processed,
						 *  so we need to have some control, which `raise` does not give. */
						let thread = pthread_self()
//						let killResult = raise(signal.rawValue)
						let killResult = pthread_kill(thread, signal.rawValue)
						if killResult != 0 {
							completionResult.errorLogs.append(("Cannot send signal to unsigactioned thread.", ["signal": "\(signal)", "kill_result": "\(killResult)"]))
						}
						
						/* Re-unblock all signals (in case a handler blocked one). */
						let sigmaskResult = pthread_sigmask(SIG_SETMASK, &emptyMask, nil)
						if sigmaskResult != 0 {
							completionResult.errorLogs.append((
								"Cannot set sigmask of thread for signal resend to empty mask. The signal resending might dead-lock. Signal will still be received by your custom dispatch handler, but the original sigaction might not be delayed or called at all.",
								["signal": "\(signal)", "sigmask_result": "\(sigmaskResult)"]
							))
						}
						
						/* Race condition!
						 * All threads should block signal handling.
						 * This is the only way I can think of. */
//						sleep(3)
						if let previousSigaction = previousSigaction {
							do {try previousSigaction.install(on: signal, revertIfIgnored: false, updateUnsigRegistrations: false)}
							catch let error as SignalHandlingError {
								throw error.upgradeToDestructive()
							}
						}
				}
			} catch {
				completionResult.error = error
			}
		} while true
	}
	
}
