import Foundation



/**
Best effort log to stderr using write (no retry on signal). For debug only.
Marked as deprecated to force a warning if used. */
@available(*, deprecated, message: "This method should never be called in production.")
internal func loggerLessThreadSafeDebugLog(_ str: String) {
	(str + "\n").utf8CString.withUnsafeBytes{ buffer in
		guard buffer.count > 0 else {return}
		_ = write(2, buffer.baseAddress! /* buffer size > 0, so !-safe */, buffer.count)
	}
}
