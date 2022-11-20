import Foundation



/**
 An ID returned by the sigaction delayers (`SigactionDelayer_*` structs) after delay registration.
 Use the ID to unregister the delay. */
public struct DelayedSigaction : Hashable {
	
	private static var latestID = 0
	
	internal var id: Int
	internal var signal: Signal
	
	internal init(signal: Signal) {
		defer {Self.latestID += 1}
		self.id = Self.latestID
		self.signal = signal
	}
	
	public static func ==(_ lhs: DelayedSigaction, _ rhs: DelayedSigaction) -> Bool {
		return lhs.id == rhs.id
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}
	
}
