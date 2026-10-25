#!/bin/bash
# Build plasma-bin/kwin-commit-finish.so. Uses the host's gcc when it has one
# and EGL headers; otherwise (e.g. on Bazzite) builds in an ubuntu:24.04
# container with podman.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

CFLAGS="-O2 -Wall -Wextra -shared -fPIC"
if command -v gcc >/dev/null && echo '#include <EGL/egl.h>' | gcc -E - >/dev/null 2>&1; then
	gcc $CFLAGS -o plasma-bin/kwin-commit-finish.so kwin-commit-finish.c -lEGL -ldl
else
	podman run --rm -v "$PWD:/w:z" docker.io/library/ubuntu:24.04 bash -c "
		apt-get update -qq &&
		apt-get install -y -qq --no-install-recommends gcc libc6-dev libegl-dev >/dev/null &&
		gcc $CFLAGS -o /w/plasma-bin/kwin-commit-finish.so /w/kwin-commit-finish.c -lEGL -ldl"
fi
echo "built plasma-bin/kwin-commit-finish.so"
