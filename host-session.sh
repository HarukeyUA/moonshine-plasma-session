#!/bin/bash
#
# Moonshine pre_command/post_command for a Bazzite Deck (Game Mode) host.
#
# Steam is single-instance per user, so a Steam already running on the host
# swallows the stream's steam:// command and the session fails (moonshine
# issue #134). In Game Mode just quitting Steam is not enough: SDDM relogs into
# Game Mode in a loop until gamescope-session gives up and runs
# switch-to-desktop-mode, which then shuts down the *streamed* Steam.
#
#   pre:  leave Game Mode cleanly, keep Plasma from autostarting Steam,
#         then quit any Steam still running on the host.
#   post: allow the Steam autostart again and, if the stream started from
#         Game Mode, return to Game Mode once the streamed Steam has exited.

STATE="$XDG_RUNTIME_DIR/moonshine-restore-game-mode"
AUTOSTART_UNIT="app-steam@autostart.service"

in_game_mode() {
    [ -n "$(systemctl --user list-units --state=active --plain --no-legend "gamescope-session-plus@*")" ]
}

wait_for_no_steam() {
    for i in $(seq 1 30); do
        ! pgrep -x steam >/dev/null && return 0
        sleep 1
    done
    return 1
}

case "$1" in
pre)
    systemctl --user mask --runtime "$AUTOSTART_UNIT" &>/dev/null
    if in_game_mode; then
        touch "$STATE"
        steamosctl switch-to-desktop-mode
        for i in $(seq 1 30); do
            ! in_game_mode && break
            sleep 1
        done
        # Leaving Game Mode on purpose is not a failed session; don't let it count
        # towards gamescope-session's recovery, which re-extracts the Steam
        # bootstrap over ~/.local/share/Steam (clobbering libraryfolders.vdf).
        rm -f /tmp/chimeraos-short-session-tracker
    fi
    if pgrep -x steam >/dev/null; then
        /usr/bin/steam -shutdown &>/dev/null
        wait_for_no_steam
    fi
    ;;
post)
    systemctl --user unmask --runtime "$AUTOSTART_UNIT" &>/dev/null
    if [ -e "$STATE" ]; then
        rm -f "$STATE"
        wait_for_no_steam && steamosctl switch-to-game-mode
    fi
    ;;
esac
exit 0
