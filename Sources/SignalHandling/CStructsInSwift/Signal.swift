import Foundation



/* Could be an enum? I’d say no to be able to represent signals we don’t know
 * are a part of the system. */
public struct Signal : RawRepresentable, Hashable, Codable, CaseIterable, CustomStringConvertible {
	
	/* Signal 0 is not considered. Because it does not exist. It is simply a
	 * special value that can be used by kill to check if a signal can be sent to
	 * a given PID. */
	public static var allCases: [Signal] {
		return (1..<NSIG).map{ Signal(rawValue: CInt($0)) }
	}
	
	/* Names are retrieved using sys_siglist, except for the floating point
	 * exception which we renamed to arithmeticError.
	 *
	 * C program to retrieve the list of names:
	 *    #include <signal.h>
	 *    #include <stdio.h>
	 *
	 *    int main(void) {
	 *    	for (int i = 1; i < NSIG; ++i) {
	 *    		printf("%d: %s - %s\n", i, sys_signame[i], sys_siglist[i]);
	 *    	}
	 *    	return 0;
	 *    } */
	
	/**
	A hand-crafted list of signals to forward to subprocesses. Please verify this
	list suits your needs before using it…
	
	- Important: As previously mentionned, this list is hand-crafted and does not
	correspond to any system development notion, or anything that I know of. */
	public static var toForwardToSubprocesses: Set<Signal> {
		return Set(arrayLiteral:
			.terminated /* Default kill */,
			.interrupt  /* Ctrl-C */,
			.quit       /* Like .interrupt, but with a Core Dump */,
			.hangup     /* Not sure about that one but might be good: The user’s terminal is disconnected */,
			.suspended  /* Ctrl-Z */,
			.continued  /* Resume stopped process (from .suspended forwarding for instance) when we are resumed */
		)
	}
	
	/* *** Program Error Signals *** */
	/* https://www.gnu.org/software/libc/manual/html_node/Program-Error-Signals.html */
	
	public static var programErrorSignals: Set<Signal> {
		return Set(arrayLiteral:
			.arithmeticError,
			.illegalInstruction,
			.segmentationFault,
			.busError,
			.abortTrap,
			.iot,
			.traceBreakpointTrap,
			.emulatorTrap,
			.badSystemCall
		)
	}
	
	/**
	- Note: FPE means Floating-Point Exception but this signal is sent for any
	arithmetic error. */
	public static let arithmeticError        = Signal(rawValue: SIGFPE)
	@available(*, unavailable, renamed: "arithmeticError")
	public static let floatingPointException = Signal(rawValue: SIGFPE)
	public static let illegalInstruction     = Signal(rawValue: SIGILL)
	public static let segmentationFault      = Signal(rawValue: SIGSEGV)
	public static let busError               = Signal(rawValue: SIGBUS)
	public static let abortTrap              = Signal(rawValue: SIGABRT)
	/** Usually the same as `abortTrap`. */
	public static let iot                    = Signal(rawValue: SIGIOT)
	public static let traceBreakpointTrap    = Signal(rawValue: SIGTRAP)
	public static let emulatorTrap           = Signal(rawValue: SIGEMT)
	public static let badSystemCall          = Signal(rawValue: SIGSYS)
	
	/* *** Termination Signals *** */
	/* https://www.gnu.org/software/libc/manual/html_node/Termination-Signals.html */
	
	public static var terminationSignals: Set<Signal> {
		return Set(arrayLiteral:
			.terminated,
			.interrupt,
			.quit,
			.killed,
			.hangup
		)
	}
	
	/** “Normal” kill signal */
	public static let terminated = Signal(rawValue: SIGTERM)
	/** Usually `Ctrl-C`. */
	public static let interrupt  = Signal(rawValue: SIGINT)
	/** Used to quit w/ generation of a core dump. Usually `Ctrl-\`. */
	public static let quit       = Signal(rawValue: SIGQUIT)
	public static let killed     = Signal(rawValue: SIGKILL)
	/** The user’s terminal disconnected */
	public static let hangup     = Signal(rawValue: SIGHUP)
	
	/* *** Alarm Signals *** */
	/* https://www.gnu.org/software/libc/manual/html_node/Alarm-Signals.html */
	
	public static var alarmSignals: Set<Signal> {
		return Set(arrayLiteral:
			.alarmClock,
			.virtualTimerExpired,
			.profilingTimerExpired
		)
	}
	
	public static let alarmClock            = Signal(rawValue: SIGALRM)
	public static let virtualTimerExpired   = Signal(rawValue: SIGVTALRM)
	public static let profilingTimerExpired = Signal(rawValue: SIGPROF)
	
	/* *** Asynchronous I/O Signals *** */
	/* https://www.gnu.org/software/libc/manual/html_node/Asynchronous-I_002fO-Signals.html */
	
	public static var asynchronousIOSignals: Set<Signal> {
		return Set(arrayLiteral:
			.ioPossible,
			.urgentIOCondition
//			.poll
		)
	}
	
	public static let ioPossible        = Signal(rawValue: SIGIO)
	public static let urgentIOCondition = Signal(rawValue: SIGURG)
	/* System V signal name similar to SIGIO */
	//	public static let poll              = Signal(rawValue: SIGPOLL)
	
	/* *** Job Control Signals *** */
	/* https://www.gnu.org/software/libc/manual/html_node/Job-Control-Signals.html */
	
	public static var jobControlSignals: Set<Signal> {
		return Set(arrayLiteral:
			.childExited,
			.continued,
			.suspendedBySignal,
			.suspended,
			.stoppedTTYInput,
			.stoppedTTYOutput
		)
	}
	
	public static let childExited       = Signal(rawValue: SIGCHLD)
	/* Obsolete name for SIGCHLD */
	//	public static let cildExited        = Signal(rawValue: SIGCLD)
	public static let continued         = Signal(rawValue: SIGCONT)
	/** Suspends the program. Cannot be handled, ignored or blocked. */
	public static let suspendedBySignal = Signal(rawValue: SIGSTOP)
	/** Suspends the program but can be handled and ignored. Usually `Ctrl-Z`. */
	public static let suspended         = Signal(rawValue: SIGTSTP)
	public static let stoppedTTYInput   = Signal(rawValue: SIGTTIN)
	public static let stoppedTTYOutput  = Signal(rawValue: SIGTTOU)
	
	/* *** Operation Error Signals *** */
	/* https://www.gnu.org/software/libc/manual/html_node/Operation-Error-Signals.html */
	
	public static var operationErrorSignals: Set<Signal> {
		return Set(arrayLiteral:
			.brokenPipe,
			.cputimeLimitExceeded,
			.filesizeLimitExceeded
		)
	}
	
	public static let brokenPipe            = Signal(rawValue: SIGPIPE)
	//	public static let resourceLost          = Signal(rawValue: SIGLOST)
	public static let cputimeLimitExceeded  = Signal(rawValue: SIGXCPU)
	public static let filesizeLimitExceeded = Signal(rawValue: SIGXFSZ)
	
	/* *** Miscellaneous Signals *** */
	/* https://www.gnu.org/software/libc/manual/html_node/Miscellaneous-Signals.html */
	
	public static var miscellaneousSignals: Set<Signal> {
		return Set(arrayLiteral:
			.userDefinedSignal1,
			.userDefinedSignal2,
			.windowSizeChanges,
			.informationRequest
		)
	}
	
	public static let userDefinedSignal1 = Signal(rawValue: SIGUSR1)
	public static let userDefinedSignal2 = Signal(rawValue: SIGUSR2)
	public static let windowSizeChanges  = Signal(rawValue: SIGWINCH)
	public static let informationRequest = Signal(rawValue: SIGINFO)
	
	public static func set(from sigset: sigset_t) -> Set<Signal> {
		var sigset = sigset
		return Set((1..<NSIG).filter{ sigismember(&sigset, $0) != 0 }.map{ Signal(rawValue: $0) })
	}
	
	public static let emptySigset: sigset_t = {
		var sigset = sigset_t()
		sigemptyset(&sigset)
		return sigset
	}()
	
	/**
	All the signals. Not exactly the same as `sigset(from: Set(allCases))`
	because this property uses the sigfillset function. In theory the result
	should be the same though. */
	public static let fullSigset: sigset_t = {
		var sigset = sigset_t()
		sigfillset(&sigset)
		return sigset
	}()
	
	public static func sigset(from setOfSignals: Set<Signal>) -> sigset_t {
		var sigset = sigset_t()
		sigemptyset(&sigset)
		for s in setOfSignals {sigaddset(&sigset, s.rawValue)}
		return sigset
	}
	
	public var rawValue: CInt
	
	public var sigset: sigset_t {
		var sigset = sigset_t()
		sigemptyset(&sigset)
		sigaddset(&sigset, rawValue)
		return sigset
	}
	
	public init(rawValue: CInt) {
		self.rawValue = rawValue
	}
	
	/** Will return `usr1` or similar for `.userDefinedSignal1` for instance. */
	public var signalName: String? {
		guard rawValue >= 0 && rawValue < NSIG else {
			return nil
		}
		
		return withUnsafePointer(to: sys_signame, { siglistPtr in
			return siglistPtr.withMemoryRebound(to: UnsafePointer<UInt8>?.self, capacity: Int(NSIG), { siglistPtrAsPointerToCStrings in
				return siglistPtrAsPointerToCStrings.advanced(by: Int(rawValue)).pointee.flatMap{ String(cString: $0) }
			})
		})
	}
	
	/**
	Return a user readable description of the signal (always in English I think). */
	public var signalDescription: String? {
		guard rawValue >= 0 && rawValue < NSIG else {
			return nil
		}
		
		return withUnsafePointer(to: sys_siglist, { siglistPtr in
			return siglistPtr.withMemoryRebound(to: UnsafePointer<UInt8>?.self, capacity: Int(NSIG), { siglistPtrAsPointerToCStrings in
				return siglistPtrAsPointerToCStrings.advanced(by: Int(rawValue)).pointee.flatMap{ String(cString: $0) }
			})
		})
	}
	
	public var description: String {
		return "SIG\((signalName ?? "\(rawValue)").uppercased())"
	}
	
}
