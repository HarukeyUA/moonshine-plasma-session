# moonshine-plasma-session

Stream a full KDE Plasma desktop through [Moonshine](https://github.com/hgaiser/moonshine) to a Moonlight client.
Plasma runs nested inside Moonshine's compositor, separate from whatever the host shows (e.g. Bazzite's Game Mode).

Set up on Bazzite (Fedora 44, Plasma 6.7, NVIDIA RTX 4070 SUPER, driver 615).

## Requirements

- Moonshine built from [HarukeyUA/moonshine](https://github.com/HarukeyUA/moonshine/tree/nested-desktop), branch `nested-desktop` (tag `v0.16.1-nested.2` or later).
  Stock Moonshine 0.16.1 lacks `wp_single_pixel_buffer_manager_v1`, without which KWin's nested backend exits on start.
  The fork also adds the per-application `steam_mode` and `scale` options used below.
- `podman` or `gcc` with EGL headers, to build the KWin hook.

## Install

```sh
./install.sh
```

This builds `plasma-bin/kwin-commit-finish.so` and copies the session files into `~/.config/moonshine`.
An existing `config.toml` and `host-session.sh` are kept; `./install.sh --with-config` overwrites them after backing them up.
Moonshine reads `config.toml` at startup, so restart it after changing applications: `sudo systemctl restart moonshine@$USER`.

## Files

| File | Purpose |
| --- | --- |
| `config.toml` | Moonshine config. The `KDE Plasma` application sets `steam_mode = false` (otherwise only Steam windows get keyboard focus) and `scale` (Plasma's own display scaling has no effect when nested). |
| `plasma-session.sh` | The application command. Starts `startplasma-wayland` on a private D-Bus session, with the Game Mode environment Moonshine inherits cleared out. |
| `plasma-xdg/startkderc` | Turns off Plasma's systemd boot, which would start the session in the user's systemd manager, shared with the host. |
| `plasma-bin/kwin_wayland` | Found first on `PATH` by `kwin_wayland_wrapper`. Runs a copy of KWin with the hook preloaded. |
| `kwin-commit-finish.c` | The hook. Makes KWin finish its GPU work before each commit. |
| `host-session.sh` | Pre/post command for the `Steam` application, which leaves and restores Game Mode around a Steam stream. Not used by the Plasma session. |

## Why the hook

KWin's nested Wayland backend renders a frame, calls `glFlush()` and commits it without any synchronization.
NVIDIA's driver attaches no implicit fences to dma-bufs, and KWin's nested backend has no explicit sync, so Moonshine can sample frames the GPU is still drawing.
The result is flicker where KWin draws last: panels and the cursor.

`kwin-commit-finish.so` wraps `KWayland::Client::Surface::commit()`, which libkwin commits its output surfaces through, and calls `glFinish()` on KWin's current context first.
It removes itself from `LD_PRELOAD` on load, so nothing KWin launches inherits it.

`/usr/bin/kwin_wayland` has file capabilities (`cap_sys_nice`), so the dynamic loader ignores `LD_PRELOAD` for it.
`plasma-bin/kwin_wayland` therefore copies it into `$XDG_RUNTIME_DIR/moonshine-kwin/` on every launch, which drops the capabilities, and runs the copy.
Copying on every launch keeps the copy in step with system KWin updates.
KWin cannot get realtime scheduling inside Moonshine's session anyway.

## Scaling

KWin's nested backend takes its scale only from the host compositor through `wp_fractional_scale_v1`.
Set it per application in `config.toml`, between 0.5 and 4.0:

```toml
[[application]]
title = "KDE Plasma"
command = ["/home/rainy/.config/moonshine/plasma-session.sh"]
steam_mode = false
scale = 2.0
```

The value applies to every client resolution, so pick it for the device you stream to most (2.0 suits a 3024x1890 MacBook stream).

## Debugging

The session logs to the user journal: `journalctl --user -u moonshine-session.service`.
The hook logs `kwin-commit-finish: active` when KWin loads it.
