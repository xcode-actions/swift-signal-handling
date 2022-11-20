import Foundation
#if canImport(System)
import System
#else
import SystemPackage
#endif



public struct Sigaction : Equatable, RawRepresentable {
	
	public static let ignoreAction = Sigaction(handler: .ignoreHandler)
	public static let defaultAction = Sigaction(handler: .defaultHandler)
	
	/**
	 Check if the given signal is ignored using `sigaction`. */
	public static func isSignalIgnored(_ signal: Signal) throws -> Bool {
		return try Sigaction(signal: signal).handler == .ignoreHandler
	}
	
	/**
	 Check if the given signal is handled with default action using `sigaction`. */
	public static func isSignalDefaultAction(_ signal: Signal) throws -> Bool {
		return try Sigaction(signal: signal).handler == .defaultHandler
	}
	
	public var mask: Set<Signal> = []
	public var flags: SigactionFlags = []
	
	public var handler: SigactionHandler
	
	public init(handler: SigactionHandler) {
		self.mask = []
		switch handler {
			case .posix:                                  self.flags = [.siginfo]
			case .ignoreHandler, .defaultHandler, .ansiC: self.flags = []
		}
		self.handler = handler
	}
	
	/**
	 Create a `Sigaction` from a `sigaction`.
	 
	 If the handler of the sigaction is `SIG_IGN` or `SIG_DFL`, we check the
	 `sa_flags` not to contains the `SA_SIGINFO` bit. If they do, we log an
	 error, as this is invalid. */
	public init(rawValue: sigaction) {
		self.mask = Signal.set(from: rawValue.sa_mask)
		self.flags = SigactionFlags(rawValue: rawValue.sa_flags)
		
#if !os(Linux)
		switch OpaquePointer(bitPattern: unsafeBitCast(rawValue.__sigaction_u.__sa_handler, to: Int.self)) {
			case OpaquePointer(bitPattern: unsafeBitCast(SIG_IGN, to: Int.self)): self.handler = .ignoreHandler
			case OpaquePointer(bitPattern: unsafeBitCast(SIG_DFL, to: Int.self)): self.handler = .defaultHandler
			default:
				if flags.contains(.siginfo) {self.handler = .posix(rawValue.__sigaction_u.__sa_sigaction)}
				else                        {self.handler = .ansiC(rawValue.__sigaction_u.__sa_handler)}
		}
#else
		switch OpaquePointer(bitPattern: unsafeBitCast(rawValue.__sigaction_handler.sa_handler, to: Int.self)) {
			case OpaquePointer(bitPattern: unsafeBitCast(SIG_IGN, to: Int.self)): self.handler = .ignoreHandler
			case OpaquePointer(bitPattern: unsafeBitCast(SIG_DFL, to: Int.self)): self.handler = .defaultHandler
			default:
				if flags.contains(.siginfo) {self.handler = .posix(rawValue.__sigaction_handler.sa_sigaction)}
				else                        {self.handler = .ansiC(rawValue.__sigaction_handler.sa_handler)}
		}
#endif
		
		if !isValid {
			SignalHandlingConfig.logger?.warning("Initialized an invalid Sigaction.")
		}
	}
	
	public init(signal: Signal) throws {
		var action = sigaction()
		guard sigaction(signal.rawValue, nil, &action) == 0 else {
			throw SignalHandlingError.nonDestructiveSystemError(Errno(rawValue: errno))
		}
		self.init(rawValue: action)
	}
	
	public var rawValue: sigaction {
		if !isValid {
			SignalHandlingConfig.logger?.warning("Getting sigaction from an invalid Sigaction.")
		}
		
		var ret = sigaction()
		ret.sa_mask = Signal.sigset(from: mask)
		ret.sa_flags = flags.rawValue
		
#if !os(Linux)
		switch handler {
			case .ignoreHandler:  ret.__sigaction_u.__sa_handler = SIG_IGN
			case .defaultHandler: ret.__sigaction_u.__sa_handler = SIG_DFL
			case .ansiC(let h):   ret.__sigaction_u.__sa_handler = h
			case .posix(let h):   ret.__sigaction_u.__sa_sigaction = h
		}
#else
		switch handler {
			case .ignoreHandler:  ret.__sigaction_handler.sa_handler = SIG_IGN
			case .defaultHandler: ret.__sigaction_handler.sa_handler = SIG_DFL
			case .ansiC(let h):   ret.__sigaction_handler.sa_handler = h
			case .posix(let h):   ret.__sigaction_handler.sa_sigaction = h
		}
#endif
		
		return ret
	}
	
	/**
	 Only one check: do the flags **not** contain `siginfo` if handler is either
	 `.ignoreHandler` or `.defaultHandler`. */
	public var isValid: Bool {
		return !flags.contains(.siginfo) || (handler != .ignoreHandler && handler != .defaultHandler)
	}
	
	/**
	 Installs the sigaction and returns the old one if different.
	 
	 It is impossible for a sigaction handler to be `nil`. If the method returns
	 `nil`, the previous handler was exactly the same as the one you installed.
	 Note however the sigaction function is always called in this method.
	 
	 If `updateUnsigRegistrations` is true (default), If there are delayed
	 sigactions registered with `SigactionDelayer_Unsig`, these registrations
	 will be updated and `sigaction` will not be called. */
	@discardableResult
	public func install(on signal: Signal, revertIfIgnored: Bool = true, updateUnsigRegistrations: Bool = true) throws -> Sigaction? {
		if updateUnsigRegistrations, let oldSigaction = SigactionDelayer_Unsig.updateOriginalSigaction(for: signal, to: self) {
			return (oldSigaction != self ? oldSigaction : nil)
		}
		
		var oldCAction = sigaction()
		var newCAction = self.rawValue
		guard sigaction(signal.rawValue, &newCAction, &oldCAction) == 0 else {
			throw SignalHandlingError.nonDestructiveSystemError(Errno(rawValue: errno))
		}
		let oldSigaction = Sigaction(rawValue: oldCAction)
		if revertIfIgnored && oldSigaction == .ignoreAction {
			guard sigaction(signal.rawValue, &oldCAction, nil) == 0 else {
				throw SignalHandlingError.destructiveSystemError(Errno(rawValue: errno))
			}
			return nil
		}
		return (oldSigaction != self ? oldSigaction : nil)
	}
	
}
