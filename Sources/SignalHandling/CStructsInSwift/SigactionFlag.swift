import Foundation



/** Flag list is from `sigaction(2)` on macOS. */
public struct SigactionFlags : OptionSet {
	
	/**
	 If this bit is set when installing a catching function for the `SIGCHLD`
	 signal, the `SIGCHLD` signal will be generated only when a child process
	 exits, not when a child process stops. */
	public static let noChildStop = SigactionFlags(rawValue: SA_NOCLDSTOP)
	
	/**
	 If this bit is set when calling `sigaction()` for the `SIGCHLD` signal, the
	 system will not create zombie processes when children of the calling process
	 exit. If the calling process subsequently issues a `wait(2)` (or
	 equivalent), it blocks until all of the calling process’s child processes
	 terminate, and then returns a value of -1 with errno set to ECHILD. */
	public static let noChildWait = SigactionFlags(rawValue: SA_NOCLDWAIT)
	
	/**
	 If this bit is set, the system will deliver the signal to the process on a
	 signal stack, specified with `sigaltstack(2)`. */
	public static let onStack = SigactionFlags(rawValue: SA_ONSTACK)
	
	/**
	 If this bit is set, further occurrences of the delivered signal are not
	 masked during the execution of the handler. */
	public static let noDefer = SigactionFlags(rawValue: SA_NODEFER)
	
	/**
	 If this bit is set, the handler is reset back to `SIG_DFL` at the moment the
	 signal is delivered. */
	public static let resetHandler = SigactionFlags(rawValue: CInt(SA_RESETHAND) /* On Linux, an UInt32 instead of Int32, so we cast… */)
	
	/** See `sigaction(2)`. */
	public static let restart = SigactionFlags(rawValue: SA_RESTART)
	
	/**
	 If this bit is set, the handler function is assumed to be pointed to by the
	 `sa_sigaction` member of struct sigaction and should match the matching
	 prototype. This bit should not be set when assigning `SIG_DFL` or `SIG_IGN`. */
	public static let siginfo = SigactionFlags(rawValue: SA_SIGINFO)
	
	public let rawValue: CInt
	
	public init(rawValue: CInt) {
		self.rawValue = rawValue
	}
	
}
