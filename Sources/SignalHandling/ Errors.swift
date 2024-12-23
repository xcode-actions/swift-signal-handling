import Foundation
#if canImport(SystemPackage)
import SystemPackage
#elseif canImport(System)
import System
#endif



public enum SignalHandlingError : Error {
	
	/**
	 Some system call has gone through, but the function could not finish.
	 Side effects are to be expected. */
	case destructiveSystemError(Errno)
	case nonDestructiveSystemError(Errno)
	
	func upgradeToDestructive() -> SignalHandlingError {
		switch self {
			case .destructiveSystemError:               return self
			case .nonDestructiveSystemError(let errno): return .destructiveSystemError(errno)
		}
	}
	
}
