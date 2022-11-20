/*
 * main.c
 * test
 *
 * Created by François Lamboley on 15/04/2021.
 */

#include <signal.h>
#include <stdio.h>



static void action(int signal) {
	fprintf(stderr, "Got %d\n", signal);
}


int main(void) {
	struct sigaction oldAction = {};
	
	sigaction(15, NULL, &oldAction);
	fprintf(stderr, "%p\n", oldAction.sa_handler);
	
	struct sigaction newAction = {};
	newAction.sa_flags = 0;
	sigemptyset(&newAction.sa_mask);
	/* We do not use sa_sigaction because it generates a warning on Linux w/ function signature `void action(int, struct __siginfo *, void *)`
	 *  because args are not exactly the same as on macOS, but would work too. */
	newAction.sa_handler = &action;
	sigaction(15, &newAction, NULL);
	fprintf(stderr, "%p\n", newAction.sa_handler);
	
	sigaction(15, NULL, &oldAction);
	fprintf(stderr, "%p\n", oldAction.sa_handler);
	
	raise(15);
	
	newAction.sa_handler = SIG_DFL;
	sigaction(15, &newAction, NULL);
	
	sigaction(15, NULL, &oldAction);
	fprintf(stderr, "%p\n", oldAction.sa_handler);
	
	return 0;
}
