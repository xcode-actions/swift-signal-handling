import Foundation

import GlobalConfModule
import Logging



public extension ConfKeys {
	/* SignalHandling conf namespace declaration. */
	struct SignalHandling {}
	var signalHandling: SignalHandling {SignalHandling()}
}


extension ConfKeys.SignalHandling {
	
	#declareConfKey("logger", Logging.Logger?.self, defaultValue: .init(label: "com.xcode-actions.signal-handling"))
	
}


extension Conf {
	
	#declareConfAccessor(\.signalHandling.logger, Logging.Logger?.self)
	
}
