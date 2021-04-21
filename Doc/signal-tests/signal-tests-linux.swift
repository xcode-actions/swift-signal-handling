import Foundation


/* WORKS IN SWIFT LINUX DOCKER IMAGE */


var doFirstTest = true
var doSecondTest = true

var ignoreAction = sigaction()
ignoreAction.sa_flags = 0
sigemptyset(&ignoreAction.sa_mask)
ignoreAction.__sigaction_handler.sa_handler = SIG_IGN

var defaultAction = sigaction()
defaultAction.sa_flags = 0
sigemptyset(&defaultAction.sa_mask)
defaultAction.__sigaction_handler.sa_handler = SIG_DFL


let signalSourceRetain: DispatchSourceSignal?
if doFirstTest {
	var oldAction = sigaction()
	var oldActionHandlerPtr: OpaquePointer?
	let sigIgnOpaque = OpaquePointer(bitPattern: unsafeBitCast(SIG_IGN, to: Int.self))
	let sigDflOpaque = OpaquePointer(bitPattern: unsafeBitCast(SIG_DFL, to: Int.self))
	
	sigaction(15, nil, &oldAction)
	oldActionHandlerPtr = OpaquePointer(bitPattern: unsafeBitCast(oldAction.__sigaction_handler.sa_handler, to: Int.self))
	print("before dispatch: ign: \(oldActionHandlerPtr == sigIgnOpaque)")
	print("before dispatch: dfl: \(oldActionHandlerPtr == sigDflOpaque)")
	print("before dispatch: mask: \(oldAction.sa_mask)")
	print("before dispatch: flags: \(oldAction.sa_flags)")
	
	var newAction = sigaction()
	newAction.sa_flags = 0
	sigemptyset(&newAction.sa_mask)
	newAction.__sigaction_handler.sa_sigaction = { signal, siginfo, threadUserContext in
		print("got \(signal) from sigaction")
	}
	//newAction.__sigaction_handler.sa_handler = SIG_IGN
	let newActionHandlerPtr = OpaquePointer(bitPattern: unsafeBitCast(newAction.__sigaction_handler.sa_handler, to: Int.self))
	sigaction(15, &newAction, nil)
	
	sigaction(15, nil, &oldAction)
	oldActionHandlerPtr = OpaquePointer(bitPattern: unsafeBitCast(oldAction.__sigaction_handler.sa_handler, to: Int.self))
	print("after sigaction: ign: \(oldActionHandlerPtr == sigIgnOpaque)")
	print("after sigaction: dfl: \(oldActionHandlerPtr == sigDflOpaque)")
	print("after sigaction: newAction: \(oldActionHandlerPtr == newActionHandlerPtr)")
	print("after sigaction: mask: \(oldAction.sa_mask)")
	print("after sigaction: flags: \(oldAction.sa_flags)")
	
	let s = DispatchSource.makeSignalSource(signal: 15)
	s.setEventHandler{
		print("got \(s.data) signal 15 from dispatch")
		sigaction(15, nil, &oldAction)
		oldActionHandlerPtr = OpaquePointer(bitPattern: unsafeBitCast(oldAction.__sigaction_handler.sa_handler, to: Int.self))
		print("in dispatch: ign: \(oldActionHandlerPtr == sigIgnOpaque)")
		print("in dispatch: dfl: \(oldActionHandlerPtr == sigDflOpaque)")
		print("in dispatch: newAction: \(oldActionHandlerPtr == newActionHandlerPtr)")
		print("in dispatch: mask: \(oldAction.sa_mask)")
		print("in dispatch: flags: \(oldAction.sa_flags)")
	}
	s.resume()
	signalSourceRetain = s /* We want the source to stay on after end of if. */
	
	sigaction(15, nil, &oldAction)
	oldActionHandlerPtr = OpaquePointer(bitPattern: unsafeBitCast(oldAction.__sigaction_handler.sa_handler, to: Int.self))
	print("after dispatch: ign: \(oldActionHandlerPtr == sigIgnOpaque)")
	print("after dispatch: dfl: \(oldActionHandlerPtr == sigDflOpaque)")
	print("after dispatch: newAction: \(oldActionHandlerPtr == newActionHandlerPtr)")
	print("after dispatch: mask: \(oldAction.sa_mask)")
	print("after dispatch: flags: \(oldAction.sa_flags)")
	
	usleep(500)
	sigaction(15, nil, &oldAction)
	oldActionHandlerPtr = OpaquePointer(bitPattern: unsafeBitCast(oldAction.__sigaction_handler.sa_handler, to: Int.self))
	print("after dispatch and delay: ign: \(oldActionHandlerPtr == sigIgnOpaque)")
	print("after dispatch and delay: dfl: \(oldActionHandlerPtr == sigDflOpaque)")
	print("after dispatch and delay: newAction: \(oldActionHandlerPtr == newActionHandlerPtr)")
	print("after dispatch and delay: mask: \(oldAction.sa_mask)")
	print("after dispatch and delay: flags: \(oldAction.sa_flags)")
	/* raise and kill are not the same in a multi-threaded env */
	//raise(15)
	kill(getpid(), 15)
	sleep(1)
	
	print("***** FIRST TEST DONE ******")
} else {
	print("***** FIRST TEST SKIPPED ******")
}


var cond = pthread_cond_t()
pthread_cond_init(&cond, nil)

if doSecondTest {
	sigaction(15, &ignoreAction, nil)
	
	var threadAttr = pthread_attr_t()
	pthread_attr_init(&threadAttr)
	pthread_attr_setdetachstate(&threadAttr, Int32(PTHREAD_CREATE_DETACHED))
//	pthread_attr_set_qos_class_np(&threadAttr, QOS_CLASS_BACKGROUND, QOS_MIN_RELATIVE_PRIORITY)
	
	var mutexAttr = pthread_mutexattr_t()
	pthread_mutexattr_init(&mutexAttr)
	pthread_mutexattr_settype(&mutexAttr, Int32(PTHREAD_MUTEX_NORMAL))
	
	var mutex = pthread_mutex_t()
	pthread_mutex_init(&mutex, &mutexAttr)
	
	var thread = pthread_t()
	pthread_create(&thread, &threadAttr, threadForSignal, nil)
	
	pthread_mutex_lock(&mutex);
	pthread_cond_wait(&cond, &mutex)
	pthread_mutex_unlock(&mutex);
	
	/* Thread is initialized and running */
	print("thread initialized and running")
	
	sigaction(15, &defaultAction, nil)
	usleep(500)
	pthread_kill(thread, 15)
//	raise(15)
//	kill(getpid(), 15)
	
	sleep(1)
	print("***** SECOND TEST DONE ******")
} else {
	print("***** SECOND TEST SKIPPED ******")
}

private func threadForSignal(_ arg: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
	pthread_cond_signal(&cond)
	repeat {
		print("pause send")
		pause()
		print("pause returned, setting sigaction back to ignore")
		sigaction(15, &ignoreAction, nil)
	} while true
}
