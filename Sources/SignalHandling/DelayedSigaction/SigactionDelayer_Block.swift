import Foundation
#if canImport(SystemPackage)
import SystemPackage
#elseif canImport(System)
import System
#endif



/**
 A way to delay the sigaction for a given signal until arbitrary handlers have allowed it.
 Use with care.
 You should understand how the delaying works before using this.
 In particular **this method does not work at all on Linux**.
 If possible, you should really use the `Unsig` strategy.
 
 First, to delay a sigaction, you have to bootstrap the signals you’ll want to delay, **before any other threads are created**.
 Technically you can bootstrap any signals you want, including those you won’t need to delay,
  but to avoid some potentially nasty side-effects, you should only ever bootstrap the signals you will need to delay.
 
 At bootstrap time, all the bootstrapped signals are blocked on the calling thread
  (which should be the main thread as the bootstrap must be called before any other thread are created).
 Then a thread is spawned, in which the bootstrapped signals are unblocked.
 These signals can now only be processed by this thread.
 
 When the first handler is registered for a given signal, we instruct the thread to block the given signal.
 Whenever the signal is received, we are notified via GCD, and then tell the thread to receive the signal via `sigsuspend`.
 
 - Important: Some (big) caveats.
 
 __On macOS__, _from what I understand_, when all threads are blocking a given signal, the system has to choose which thread to send the signal to.
 And it might not be the one we have chosen to process signals… so we sometimes have to re-send the signal to our thread!
 In which case we lose the info in `siginfo_t`, and a thread is stuck with a pending signal forever…
 (I have actually not observed another behavior on macOS.)
 
 __On Linux__, the system sends the signal to _all_ threads and assigns the thread as soon as one is ready to handle the signal, so this strategy works.
 However, contrary to what the man page says, it seems `libdispatch` _does_ modify the sigaction when a signal source is installed.
 It seems saving the sigaction prior to registering the signal source, then setting it back after the registration of the source
  fixes the issue though, so we did that.
 This solution seems weak though, and might break in the future.
 
 - Important: An important side-effect of this technique is if a bootstrapped signal is then sent to a specific thread, the signal will be blocked.
 Forever.
 Because of this, you really should not bootstrap whatever signal you want.
 For example, the `SIGILL` signal (illegal instruction) is sent to the offending thread, not the process.
 If you use it for a delayed sigaction, when the signal is sent,
  the thread that triggered that signal will block forever
  (all signals bootstrapped are blocked on all threads except the internal thread). */
public enum SigactionDelayer_Block {
	
	/**
	 Prepare the process for delayed sigaction by blocking all signals on the main thread and spawning a thread to handle signals.
	 
	 Delayed sigaction is done by blocking delayed signals until the time has come to call the sigaction handler.
	 If any thread does not block the delayed signal, the sigaction will be called before its time!
	 
	 - Note: How do we know a signal has arrived if it is blocked?
	 We use libdispatch to be notified when a new signal arrives.
	 libdispatch uses `kqueue` on BSD and `signalfd` on Linux.
	 Signals are still sent to `kqueue` and `signalfd` when they are blocked, so it works.
	 
	 - Important: Must be called before any thread is spawned.
	 - Important: You should not use `pthread_sigmask` to sigprocmask (nor anything to unblock signals) after calling this method. */
	public static func bootstrap(for signals: Set<Signal>) throws {
		guard !bootstrapDone else {
			fatalError("DelayedSigaction can be bootstrapped only once")
		}
		
		var signalsSigset = Signal.sigset(from: signals)
		let ret = pthread_sigmask(SIG_SETMASK, &signalsSigset, nil /* old signals */)
		if ret != 0 {
			throw SignalHandlingError.nonDestructiveSystemError(Errno(rawValue: ret))
		}
		
		var error: Error?
		let group = DispatchGroup()
		group.enter()
		Thread.detachNewThread{
			Thread.current.name = "com.xcode-actions.blocked-signals-thread"
			
			/* Unblock all signals in this thread. */
			var noSignals = Signal.emptySigset
			let ret = pthread_sigmask(SIG_SETMASK, &noSignals, nil /* old signals */)
			if ret != 0 {
				error = SignalHandlingError.destructiveSystemError(Errno(rawValue: ret))
			}
			group.leave()
			
			if ret == 0 {
				blockedSignalsThreadLoop()
			}
		}
		group.wait()
		if let e = error {throw e}
	}
	
	public static func registerDelayedSigaction(_ signal: Signal, handler: @escaping DelayedSigactionHandler) throws -> DelayedSigaction {
		return try signalProcessingQueue.sync{
			try registerDelayedSigactionOnQueue(signal, handler: handler)
		}
	}
	
	public static func unregisterDelayedSigaction(_ delayedSigaction: DelayedSigaction) throws {
		return try signalProcessingQueue.sync{
			try unregisterDelayedSigactionOnQueue(delayedSigaction)
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
						catch {
							SignalHandlingConfig.logger?.error(
								"Cannot unregister delayed sigaction for in recovery handler of registerDelayedSigactions. The signal will stay blocked, probably forever.",
								metadata: ["signal": "\(signal)", "error": "\(error)"]
							)
						}
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
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private enum ThreadSync : Int {
		
		enum Action {
			case nop
			case drop(Signal)
			case block(Signal)
			case unblock(Signal)
			case suspend(for: Signal)
			case endThread /* Not actually used, but implemented. Would be useful in an unboostrap method. */
			
			var isNop: Bool {
				if case .nop = self {return true}
				return false
			}
		}
		
		static let lock = NSConditionLock(condition: Self.nothingToDo.rawValue)
		
		static var action: Action = .nop
		static var error: Error?
		
		case nothingToDo
		case actionInThread
		case waitActionCompletion
		
	}
	
	private struct BlockedSignal {
		
		var dispatchSource: DispatchSourceSignal
		var handlers = [DelayedSigaction: DelayedSigactionHandler]()
		
	}
	
	private static let signalProcessingQueue = DispatchQueue(label: "com.xcode-actions.blocked-signals-processing-queue")
	
	private static var bootstrapDone = false
	private static var blockedSignals = [Signal: BlockedSignal]()
	
	private static func executeOnThread(_ action: ThreadSync.Action) throws {
		do {
#if !os(Linux)
			ThreadSync.lock.lock(whenCondition: ThreadSync.nothingToDo.rawValue)
#else
			/* Locking before a date too far in the future crashes on Linux.
			 * https://bugs.swift.org/browse/SR-14676 */
			while !ThreadSync.lock.lock(whenCondition: ThreadSync.nothingToDo.rawValue, before: Date(timeIntervalSinceNow: 24*60*60)) {}
#endif
			defer {ThreadSync.lock.unlock(withCondition: ThreadSync.actionInThread.rawValue)}
			assert(ThreadSync.error == nil, "non-nil error but acquired lock in nothingToDo state.")
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
				ThreadSync.error = nil
				ThreadSync.lock.unlock(withCondition: ThreadSync.nothingToDo.rawValue)
			}
			assert(ThreadSync.action.isNop, "non-nop action but acquired lock in waitActionCompletion state.")
			if let e = ThreadSync.error {
				throw e
			}
		}
	}
	
	private static func registerDelayedSigactionOnQueue(_ signal: Signal, handler: @escaping DelayedSigactionHandler) throws -> DelayedSigaction {
		let delayedSigaction = DelayedSigaction(signal: signal)
		
		var blockedSignal: BlockedSignal
		if let ds = blockedSignals[signal] {
			blockedSignal = ds
		} else {
#if os(Linux)
			let currentSigaction = try Sigaction(signal: signal)
#endif
			
			try executeOnThread(.block(signal))
			
			let dispatchSourceSignal = DispatchSource.makeSignalSource(signal: signal.rawValue, queue: signalProcessingQueue)
			/* Apparently the dispatchSourceSignal does not need to be weak in the handler because the handler is released when the source is canceled.
			 * I manually tested this and found no confirmation or infirmation of this in the documentation. */
			dispatchSourceSignal.setEventHandler{ processSignalsOnQueue(signal: signal, count: dispatchSourceSignal.data) }
			dispatchSourceSignal.activate()
			
#if os(Linux)
			/* On Linux, the sigaction must be reset after a dispatch source signal is registerd because libdispatch _does_ modify the sigaction.
			 * It turns out we cannot update the sigaction synchronously here though,
			 *  because libdispatch does not update the sigaction directly,
			 *  so we do it asynchronously.
			 * This is sooooo fragile (and introduces a race condition too).
			 * https://github.com/apple/swift-corelibs-libdispatch/pull/560 */
			signalProcessingQueue.async{
				do {try currentSigaction.install(on: signal)}
				catch {
					SignalHandlingConfig.logger?.error(
						"Cannot set original sigaction back for signal after signal source activation. You might never be called in the sigaction handler and get an infinite loop of signal calls once this signal has been sent once.",
						metadata: ["signal": "\(signal)", "error": "\(error)"]
					)
				}
			}
#endif
			
			blockedSignal = BlockedSignal(dispatchSource: dispatchSourceSignal)
		}
		
		assert(blockedSignal.handlers[delayedSigaction] == nil)
		blockedSignal.handlers[delayedSigaction] = handler
		blockedSignals[signal] = blockedSignal
		
		return delayedSigaction
	}
	
	private static func unregisterDelayedSigactionOnQueue(_ delayedSigaction: DelayedSigaction) throws {
		let signal = delayedSigaction.signal
		
		guard var blockedSignal = blockedSignals[signal] else {
			/* We trust our source not to have an internal logic error.
			 * If the delayed sigaction is not found, it is because the callee called unregister twice on the same delayed sigaction. */
			SignalHandlingConfig.logger?.error("Delayed sigaction unregistered more than once.", metadata: ["signal": "\(signal)"])
			return
		}
		assert(!blockedSignal.handlers.isEmpty, "INTERNAL ERROR: handlers should never be empty because when it is, the whole delayed signal should be removed.")
		
		guard blockedSignal.handlers.removeValue(forKey: delayedSigaction) != nil else {
			/* Same here.
			 * If the delayed sigaction was not in the handlers, it can only be because the callee called unregister twice with the object. */
			SignalHandlingConfig.logger?.error("Delayed sigaction unregistered more than once.", metadata: ["signal": "\(signal)"])
			return
		}
		
		if !blockedSignal.handlers.isEmpty {
			/* We have nothing more to do except update the delayed signals:
			 *  there are more delayed signals that have been registered for this signal,
			 *  so we cannot unblock the signal. */
			blockedSignals[signal] = blockedSignal
			return
		}
		
		/* Now we have removed **all** delayed sigactions on the given signal.
		 * Let’s unblock the signal! */
		try executeOnThread(.unblock(signal))
		blockedSignal.dispatchSource.cancel()
		
		/* Finally, once the sigaction has been restored to the original value, we can remove the unsigactioned signal from the list. */
		blockedSignals.removeValue(forKey: signal)
	}
	
	/** Must always be called on the `signalProcessingQueue`. */
	private static func processSignalsOnQueue(signal: Signal, count: UInt) {
		SignalHandlingConfig.logger?.debug("Processing signals, called from libdispatch.", metadata: ["signal": "\(signal)", "count": "\(count)"])
		
		/* Get the delayed signal for the given signal. */
		guard let blockedSignal = blockedSignals[signal] else {
			SignalHandlingConfig.logger?.error("INTERNAL ERROR: nil delayed signal.", metadata: ["signal": "\(signal)"])
			return
		}
		
		for _ in 0..<count {
			let group = DispatchGroup()
			var runOriginalHandlerFinal = true
			for (_, handler) in blockedSignal.handlers {
				group.enter()
				handler(signal, { runOriginalHandler in
					runOriginalHandlerFinal = runOriginalHandlerFinal && runOriginalHandler
					group.leave()
				})
			}
			group.wait()
			
			/* All the handlers have responded, we now know whether to allow or drop the signal. */
			do {try executeOnThread(runOriginalHandlerFinal ? .suspend(for: signal) : .drop(signal))}
			catch {
				SignalHandlingConfig.logger?.error(
					"Error while \(runOriginalHandlerFinal ? "suspending thread" : "dropping signal in thread").",
					metadata: ["signal": "\(signal)", "error": "\(error)"]
				)
			}
		}
	}
	
	private static func blockedSignalsThreadLoop() {
		runLoop: repeat {
//			loggerLessThreadSafeDebugLog("🧵 New blocked signals thread loop…")
		
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
			
			assert(ThreadSync.error == nil, "non-nil error but acquired lock in actionInThread state.")
			
			do {
				switch ThreadSync.action {
					case .nop:
						(/*nop*/)
//						loggerLessThreadSafeDebugLog("🧵 Processing nop action…")
						assertionFailure("nop action while being locked w/ action in thread")
						
					case .endThread:
//						loggerLessThreadSafeDebugLog("🧵 Processing endThread action…")
						break runLoop
						
					case .block(let signal):
//						loggerLessThreadSafeDebugLog("🧵 Processing block action for \(signal)…")
						var sigset = signal.sigset
						let ret = pthread_sigmask(SIG_BLOCK, &sigset, nil /* old signals */)
						if ret != 0 {
							throw SignalHandlingError.destructiveSystemError(Errno(rawValue: ret))
						}
						
					case .unblock(let signal):
//						loggerLessThreadSafeDebugLog("🧵 Processing unblock action for \(signal)…")
						var sigset = signal.sigset
						let ret = pthread_sigmask(SIG_UNBLOCK, &sigset, nil /* old signals */)
						if ret != 0 {
							throw SignalHandlingError.destructiveSystemError(Errno(rawValue: ret))
						}
						
					case .suspend(for: let signal):
//						loggerLessThreadSafeDebugLog("🧵 Processing suspend action for \(signal)…")
						let isIgnored = try Sigaction.isSignalIgnored(signal)
						var sigset = sigset_t()
						if !isIgnored {
							/* We update the sigset only when signal is not ignored
							 *  because it is used only in that case and this is getting the current sigmask can fail. */
							let ret = pthread_sigmask(SIG_SETMASK, nil /* new signals */, &sigset)
							if ret != 0 {
								throw SignalHandlingError.nonDestructiveSystemError(Errno(rawValue: ret))
							}
							sigdelset(&sigset, signal.rawValue)
						}
						/* Let’s get the pending signals on this thread. */
						var pendingSignals = sigset_t()
						let ret = sigpending(&pendingSignals)
						/* If sigpending failed, we assume the signal is pending. */
						if ret != 0 || !Signal.set(from: pendingSignals).contains(signal) {
							/* The signal is not pending on our thread.
							 * Which mean it is probably pending on some other thread, forever. */
//							loggerLessThreadSafeDebugLog("🧵 Resending signal to manager thread \(signal)…")
							pthread_kill(pthread_self(), signal.rawValue)
						}
						if !isIgnored {
							/* Only suspend process if signal is not ignored or sigsuspend would not return.
							 * I know there is a race condition. */
//							loggerLessThreadSafeDebugLog("🧵 Calling sigsuspend for \(signal)…")
							sigsuspend(&sigset)
						}
						
					case .drop(let signal):
//						loggerLessThreadSafeDebugLog("🧵 Processing drop action for \(signal)…")
						var sigset = sigset_t()
						let ret = pthread_sigmask(SIG_SETMASK, nil /* new signals */, &sigset)
						if ret != 0 {
							throw SignalHandlingError.nonDestructiveSystemError(Errno(rawValue: ret))
						}
						sigdelset(&sigset, signal.rawValue)
						
						let oldAction = try Sigaction.ignoreAction.install(on: signal, revertIfIgnored: false, updateUnsigRegistrations: false)
						/* Will not hurt, the signal is ignore anyway (yes, there is a race condition, I know). */
						pthread_kill(pthread_self(), signal.rawValue)
						/* No sigsuspend. Would block because signal is ignored. */
						if let oldAction = oldAction {
							do {try oldAction.install(on: signal, revertIfIgnored: false, updateUnsigRegistrations: false)}
							catch let error as SignalHandlingError {
								throw error.upgradeToDestructive()
							}
						}
				}
			} catch {
				ThreadSync.error = error
			}
		} while true
	}
	
}
