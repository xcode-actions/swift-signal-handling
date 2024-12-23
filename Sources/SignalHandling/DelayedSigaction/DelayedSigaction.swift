import Foundation



/**
 An ID returned by the sigaction delayers (`SigactionDelayer_*` structs) after delay registration.
 Use the ID to unregister the delay. */
public struct DelayedSigaction : Hashable {
	
	internal var id: UUID
	internal var signal: Signal
	
	internal init(signal: Signal) {
		self.id = .init()
		self.signal = signal
	}
	
	public static func ==(_ lhs: DelayedSigaction, _ rhs: DelayedSigaction) -> Bool {
		return lhs.id == rhs.id
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
}
