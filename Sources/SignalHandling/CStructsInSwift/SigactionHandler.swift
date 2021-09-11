import Foundation



/**
 A `sigaction` handler.
 
 Two `SigactionHandler`s are equal iif their cases are equal and the handler
 they contain point to the same address (if applicable). */
public enum SigactionHandler : Equatable {
	
	/* The ignore and default handlers are special cases represented respectively
	 * by the `SIG_IGN` and `SIG_DFL` values in C.
	 * We choose the represent them using a special case in the enum. You should
	 * not (though you could) use `.ansiC(SIG_IGN)` (it is not possible with
	 * `SIG_DFL` because `SIG_DFL` is optional… and nil).
	 * In particular, `.ignoreHandler != .ansiC(SIG_IGN)` */
	case ignoreHandler
	case defaultHandler
	
	case ansiC(@convention(c) (_ signalID: Int32) -> Void)
	case posix(@convention(c) (_ signalID: Int32, _ siginfo: UnsafeMutablePointer<siginfo_t>?, _ userThreadContext: UnsafeMutableRawPointer?) -> Void)
	
	public static func ==(lhs: SigactionHandler, rhs: SigactionHandler) -> Bool {
		switch (lhs, rhs) {
			case (.ignoreHandler, .ignoreHandler), (.defaultHandler, .defaultHandler):
				return true
				
			case (.ansiC, .ansiC), (.posix, .posix):
				return lhs.asOpaquePointer == rhs.asOpaquePointer
				
				/* Using this matching patterns instead of simply default, we force
				 * a compilation error in case more cases are added later. */
			case (.ignoreHandler, _), (.defaultHandler, _), (.ansiC, _), (.posix, _):
				return false
		}
	}
	
	var asOpaquePointer: OpaquePointer? {
		switch self {
			case .ignoreHandler:  return OpaquePointer(bitPattern: unsafeBitCast(SIG_IGN, to: Int.self))
			case .defaultHandler: return OpaquePointer(bitPattern: unsafeBitCast(SIG_DFL, to: Int.self))
			case .ansiC(let h):   return OpaquePointer(bitPattern: unsafeBitCast(h, to: Int.self))
			case .posix(let h):   return OpaquePointer(bitPattern: unsafeBitCast(h, to: Int.self))
		}
	}
	
}
