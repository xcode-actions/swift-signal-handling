#!/bin/bash
set -uo pipefail

readonly LINUX_SWIFT_IMAGE="swift:5.3.3"

# This can only be run on macOS.
test "$(uname -s)" = "Darwin"

cd "$(dirname "$0")"

echo "*** RUNNING TEST SIGACTION (C) ON MACOS"
make signal-test-sigaction && ./signal-test-sigaction
rm signal-test-sigaction

echo
echo
echo "*** RUNNING TEST SIGACTION (C) ON LINUX"
docker run --rm -it -v "$(pwd):/tmp/cwd" --workdir /tmp/cwd --security-opt=seccomp:unconfined --entrypoint bash "$LINUX_SWIFT_IMAGE" -c '
	make signal-test-sigaction && ./signal-test-sigaction; rm signal-test-sigaction
'

echo
echo
echo "*** RUNNING TEST BLOCKED (C) ON MACOS"
make signal-test-blocked && ./signal-test-blocked
rm signal-test-blocked

echo
echo
echo "*** RUNNING TEST BLOCKED (C) ON LINUX"
docker run --rm -it -v "$(pwd):/tmp/cwd" --workdir /tmp/cwd --security-opt=seccomp:unconfined --entrypoint bash "$LINUX_SWIFT_IMAGE" -c '
	CC=clang CFLAGS="-I/usr/lib/swift -fblocks" LDFLAGS="-L/usr/lib/swift/linux -lpthread -ldispatch -lBlocksRuntime" make signal-test-blocked && LD_LIBRARY_PATH="/usr/lib/swift/linux" ./signal-test-blocked
	rm signal-test-blocked
'

echo
echo
echo "*** RUNNING GENERIC TESTS (SWIFT) ON MACOS"
# We must compile, when run via swift as a script, some signal are handled by Swift itself.
swiftc ./signal-tests-macos.swift && ./signal-tests-macos
rm signal-tests-macos

echo
echo
echo "*** RUNNING GENERIC TESTS (SWIFT) ON LINUX"
docker run --rm -it -v "$(pwd):/tmp/cwd" --workdir /tmp/cwd --security-opt=seccomp:unconfined --entrypoint bash "$LINUX_SWIFT_IMAGE" -c '
	swiftc -o ./signal-tests-linux ./signal-tests-linux.swift && ./signal-tests-linux; rm signal-tests-linux
'
