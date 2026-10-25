#!/bin/bash
# Build the KWin hook and install the session files into ~/.config/moonshine.
# config.toml and host-session.sh are only installed when missing; pass
# --with-config to overwrite them (the old ones are backed up).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
DEST="$HOME/.config/moonshine"

./build.sh

mkdir -p "$DEST/plasma-bin" "$DEST/plasma-xdg"
install -m 0755 plasma-session.sh "$DEST/"
install -m 0644 kwin-commit-finish.c "$DEST/"
install -m 0755 plasma-bin/kwin_wayland plasma-bin/kwin-commit-finish.so "$DEST/plasma-bin/"
install -m 0644 plasma-xdg/startkderc "$DEST/plasma-xdg/"

for f in config.toml host-session.sh; do
	if [ ! -e "$DEST/$f" ]; then
		install -m 0644 "$f" "$DEST/$f"
	elif [ "${1:-}" = "--with-config" ]; then
		cp "$DEST/$f" "$DEST/$f.bak-$(date +%Y%m%d-%H%M%S)"
		install -m 0644 "$f" "$DEST/$f"
	else
		echo "kept existing $DEST/$f (use --with-config to overwrite)"
	fi
done
chmod +x "$DEST/host-session.sh"

# Undo any container relabeling of copied files.
command -v restorecon >/dev/null && restorecon -R "$DEST" 2>/dev/null || true
echo "installed into $DEST"
