#!/bin/bash
#
# Moonshine application command: a full KDE Plasma desktop nested inside
# Moonshine's compositor. KWin picks its Wayland backend because Moonshine
# sets WAYLAND_DISPLAY; this needs a Moonshine build with
# wp_single_pixel_buffer_manager_v1 (HarukeyUA/moonshine nested-desktop), and
# the app entry needs steam_mode = false so the desktop gets keyboard focus.
#
#   dbus-run-session: a private session bus, so this Plasma doesn't fight
#       Game Mode or a host Plasma over D-Bus names, and D-Bus activated apps
#       and portals start inside the stream instead of on the host.
#   plasma-xdg/startkderc: turns off systemd boot. With it on, startplasma
#       starts plasma-workspace.target in the user's systemd manager, which is
#       shared with the host and lacks this stream's display and audio env.
#   plasma-bin/kwin_wayland: kwin_wayland_wrapper runs kwin_wayland from
#       PATH; this one preloads kwin-commit-finish.so, which makes KWin finish
#       its GPU work before each commit (see kwin-commit-finish.c).

DIR="$(dirname "$(readlink -f "$0")")"

# Moonshine's own Xwayland; KWin starts a separate one for the desktop.
unset DISPLAY

# Moonshine copies the user's systemd environment, which in Game Mode holds
# gamescope's session variables and the seat0 logind session. Plasma would
# otherwise act on that session (locking, idle) and Steam would think it runs
# under gamescope.
unset XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION XDG_SESSION_TYPE \
    XDG_SESSION_ID XDG_SESSION_PATH XDG_SESSION_CLASS XDG_SEAT XDG_SEAT_PATH XDG_VTNR \
    GAMESCOPE_WAYLAND_DISPLAY STEAM_GAME_DISPLAY_0 ENABLE_MOONSHINE_WSI
for var in $(compgen -v STEAM_GAMESCOPE_); do unset "$var"; done

# KWin's nested backend can put the cursor and up to four windows (panels,
# ...) on their own subsurfaces, handing other clients' buffers to Moonshine
# unsynchronized. Composite everything into KWin's own, finished frame.
export KWIN_USE_OVERLAYS=0 KWIN_FORCE_SW_CURSOR=1

export PATH="$DIR/plasma-bin:$PATH"
export XDG_CONFIG_DIRS="$DIR/plasma-xdg:${XDG_CONFIG_DIRS:-/etc/xdg}"
exec dbus-run-session -- startplasma-wayland
