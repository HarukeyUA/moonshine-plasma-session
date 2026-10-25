// LD_PRELOAD hook for a kwin_wayland nested inside Moonshine.
//
// KWin's nested Wayland backend renders a frame, calls glFlush() and commits
// the buffer without any sync. The NVIDIA driver attaches no implicit fences
// to dma-bufs, and the host has no explicit sync to use, so Moonshine can
// sample a frame the GPU is still drawing: half-drawn frames flicker,
// mostly where KWin draws last (panels, the cursor).
//
// Wrap KWayland::Client::Surface::commit(), which libkwin commits its output
// surfaces through, and finish the current GL context's work before each
// commit.
#define _GNU_SOURCE
#include <EGL/egl.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

#define COMMIT_SYMBOL "_ZN8KWayland6Client7Surface6commitENS1_10CommitFlagE"

typedef void (*commit_fn)(void *self, int flag);

__attribute__((constructor)) static void init(void) {
	// Keep the hook out of everything KWin launches.
	unsetenv("LD_PRELOAD");
	fprintf(stderr, "kwin-commit-finish: active\n");
}

// KWayland::Client::Surface::commit(KWayland::Client::Surface::CommitFlag)
void _ZN8KWayland6Client7Surface6commitENS1_10CommitFlagE(void *self, int flag) {
	static commit_fn real_commit;
	static void (*gl_finish)(void);
	if (!real_commit) {
		real_commit = (commit_fn)dlsym(RTLD_NEXT, COMMIT_SYMBOL);
		gl_finish = (void (*)(void))eglGetProcAddress("glFinish");
	}
	static int logged;
	const int current = eglGetCurrentContext() != EGL_NO_CONTEXT;
	if (gl_finish && current) {
		gl_finish();
	}
	if (logged < 2 && (current || !logged)) {
		fprintf(stderr, "kwin-commit-finish: commit with%s a current GL context\n", current ? "" : "out");
		logged = current ? 2 : 1;
	}
	real_commit(self, flag);
}
