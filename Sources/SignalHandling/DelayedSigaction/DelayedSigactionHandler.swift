import Foundation



/**
 Handler called when a delayed sigaction signal is received.
 Handler shall call the passed handler when sigaction is ready to be called, or dropped.
 
 - Note: The sigaction might not be called as soon as the handler is called, or not at all.
 Multiple clients can delay the sigaction, and all clients must allow it to be sent for the sigaction to be sent.
 
 - Parameter signal: The signal that triggered the delayed sigaction.
 - Parameter sigactionAllowedHandler: The handler to call when the sigaction can be triggered or dropped.
 - Parameter allowSigaction: Whether the sigaction handler should be called, or the signal should be dropped. */
public typealias DelayedSigactionHandler = (_ signal: Signal, _ sigactionAllowedHandler: @escaping (_ allowSigaction: Bool) -> Void) -> Void
