import Foundation

import Logging



public enum SignalHandlingConfig {
	
	public static var logger: Logging.Logger? = {
		return Logger(label: "com.xcode-actions.signal-handling")
	}()
	
}
