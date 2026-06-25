#!/usr/bin/env bash
# Set up GPaste — the native GNOME clipboard manager — giving searchable
# clipboard history across every app (terminal, browser, …) on GNOME Wayland.
#
# Why GPaste and not clipse/cliphist:
#   Those record history via `wl-paste --watch`, which needs the wlroots
#   data-control protocol. GNOME's Mutter compositor does NOT implement it, so
#   their listeners can never capture history on GNOME. GPaste uses GNOME's own
#   clipboard APIs and works natively — no polling, no hacks.
#
# Idempotent — safe to re-run (run it again after the first login if the
# org.gnome.GPaste schema wasn't present yet).

set -euo pipefail

EXT_UUID="GPaste@gnome-shell-extensions.gnome.org"

has_gpaste_schema() {
    gsettings list-schemas 2>/dev/null | grep -q '^org.gnome.GPaste$'
}

# ── 1. Packages (need sudo) ───────────────────────────────────────────────────
if ! has_gpaste_schema; then
    echo "Installing GPaste (needs sudo)…"
    if command -v apt >/dev/null; then
        # Non-fatal: if sudo/apt is unavailable, still apply what we can.
        if ! { sudo apt-get update -qq && sudo apt-get install -y gpaste-2 gnome-shell-extension-gpaste; }; then
            echo "WARNING: couldn't install GPaste automatically." >&2
            echo "         Run: sudo apt install gpaste-2 gnome-shell-extension-gpaste" >&2
        fi
    else
        echo "WARNING: install gpaste-2 + gnome-shell-extension-gpaste with your package manager." >&2
    fi
fi

# ── 2. Free Super+V from the message tray (Super+M still toggles it) ──────────
tray="$(gsettings get org.gnome.shell.keybindings toggle-message-tray 2>/dev/null || echo '')"
if [[ "$tray" == *"<Super>v"* ]]; then
    gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>m']"
    echo "Freed Super+V from toggle-message-tray."
fi

# ── 3. GPaste settings (schema exists only once the package is installed) ─────
if has_gpaste_schema; then
    gsettings set org.gnome.GPaste max-history-size 250
    gsettings set org.gnome.GPaste max-displayed-history-size 40
    gsettings set org.gnome.GPaste track-changes true
    gsettings set org.gnome.GPaste save-history true
    gsettings set org.gnome.GPaste images-support true
    # Super+V opens the searchable history (GNOME Shell menu, type to filter).
    # show-history is a single-string accelerator (type 's'), NOT an array —
    # passing "['<Super>v']" stores a literal invalid accel that won't bind.
    gsettings set org.gnome.GPaste show-history '<Super>v'
    echo "Applied GPaste settings — Super+V opens searchable history."
else
    echo "NOTE: org.gnome.GPaste schema not present yet."
    echo "      Log in again (or finish the apt install) and re-run this script"
    echo "      to apply settings + the Super+V binding."
fi

# ── 4. Enable the GNOME Shell extension ───────────────────────────────────────
if command -v gnome-extensions >/dev/null; then
    if gnome-extensions enable "$EXT_UUID" 2>/dev/null; then
        echo "Enabled GNOME Shell extension: $EXT_UUID"
    else
        echo "Enable the extension after relogin: gnome-extensions enable $EXT_UUID"
    fi
fi

cat <<'EOF'

Done. Final step: log out and back in (Wayland can't reload GNOME Shell live)
so the GPaste daemon + extension start. Then:

  • Copy things anywhere (browser, nvim, terminal — all one clipboard now).
  • Super+V  → history menu; start typing to search.
  • Click / Enter an entry → it's copied; paste with Ctrl+V in the target app.

To snapshot any further tweaks for a new machine, run:
  dconf dump /org/gnome/GPaste/ > clipboard/gpaste-settings.dconf
and load them on restore with:  dconf load /org/gnome/GPaste/ < clipboard/gpaste-settings.dconf
EOF
