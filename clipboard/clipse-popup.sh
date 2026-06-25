#!/usr/bin/env bash
# Floating clipboard-history picker, bound to a global GNOME shortcut (Super+V).
#
# Opens clipse in a dedicated WezTerm window. clipse copies the chosen entry to
# the system clipboard and exits — WezTerm then closes the window, so the picker
# feels like a popup. Paste with Ctrl+V into whatever app had focus (browser,
# editor, …). The listener daemon (clipse --listen, started via autostart) is
# what records history; this script only shows the picker.
#
# Absolute paths: GNOME launches custom shortcuts with a minimal PATH.

WEZTERM="$HOME/.local/bin/wezterm"
CLIPSE="$HOME/.local/bin/clipse"
command -v wezterm >/dev/null && WEZTERM="$(command -v wezterm)"
command -v clipse  >/dev/null && CLIPSE="$(command -v clipse)"

exec "$WEZTERM" start --class clipse-popup -- "$CLIPSE"
