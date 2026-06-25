#!/usr/bin/env bash
# Set up a system-wide clipboard history manager (clipse) that works across
# WezTerm, tmux, nvim AND GUI apps (browser, etc.) on GNOME Wayland.
#
# What it does (all idempotent — safe to re-run):
#   1. Installs wl-clipboard (apt) so the whole stack shares ONE Wayland
#      CLIPBOARD selection instead of straddling X11/Wayland.
#   2. Installs the pinned clipse binary into ~/.local/bin (no Go needed).
#   3. Drops config.json + custom_theme.json (Catppuccin Mocha) into
#      ~/.config/clipse, backing up any existing ones.
#   4. Installs the clipse-popup launcher into ~/.local/bin.
#   5. Autostarts the clipse listener (~/.config/autostart/clipse.desktop).
#   6. Binds Super+V (GNOME) to the popup, freeing it from toggle-message-tray
#      (which keeps Super+M).
#
# After install, paste flow is: Super+V -> j/k or /search -> Enter -> Ctrl+V.

set -euo pipefail

CLIPSE_VERSION="v1.2.1"
REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/clipse"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"

mkdir -p "$BIN_DIR" "$CFG_DIR" "$AUTOSTART_DIR"

backup_if_real_file() {
    # Back up a regular file (not a symlink we own) before overwriting.
    local path="$1"
    if [[ -f "$path" && ! -L "$path" ]]; then
        local backup="$path.bak.$(date +%Y%m%d-%H%M%S)"
        echo "Backing up existing $path -> $backup"
        cp -p "$path" "$backup"
    fi
}

# ── 1. wl-clipboard (the Layer-1 unification) ────────────────────────────────
if [[ -n "${WAYLAND_DISPLAY:-}" ]] && ! command -v wl-copy >/dev/null; then
    echo "Installing wl-clipboard (needs sudo)…"
    if command -v apt >/dev/null; then
        # Non-fatal: if sudo/apt is unavailable, keep setting everything else up
        # and let the user install wl-clipboard manually.
        if ! { sudo apt-get update -qq && sudo apt-get install -y wl-clipboard; }; then
            echo "WARNING: couldn't install wl-clipboard automatically." >&2
            echo "         Run: sudo apt install wl-clipboard   (clipse needs it on Wayland)" >&2
        fi
    else
        echo "WARNING: install wl-clipboard with your package manager — clipse needs it on Wayland." >&2
    fi
fi

# ── 2. clipse binary ─────────────────────────────────────────────────────────
need_clipse=1
if command -v clipse >/dev/null && clipse -v 2>/dev/null | grep -q "$CLIPSE_VERSION"; then
    need_clipse=0
    echo "clipse $CLIPSE_VERSION already installed at $(command -v clipse)"
fi
if [[ "$need_clipse" == 1 ]]; then
    arch="$(uname -m)"
    case "$arch" in
        x86_64) asset_arch="amd64" ;;
        aarch64|arm64) asset_arch="arm64" ;;
        *) echo "Unsupported arch: $arch — install clipse manually." >&2; exit 1 ;;
    esac
    variant="x11"; [[ -n "${WAYLAND_DISPLAY:-}" ]] && variant="wayland"
    url="https://github.com/savedra1/clipse/releases/download/${CLIPSE_VERSION}/clipse_${CLIPSE_VERSION}_linux_${variant}_${asset_arch}.tar.gz"
    echo "Downloading clipse $CLIPSE_VERSION ($variant/$asset_arch)…"
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/clipse.tgz" "$url"
    tar xzf "$tmp/clipse.tgz" -C "$tmp"
    bin="$(find "$tmp" -maxdepth 2 -type f -name 'clipse*' ! -name '*.tar.gz' | head -1)"
    install -m755 "$bin" "$BIN_DIR/clipse"
    rm -rf "$tmp"
    echo "Installed: $BIN_DIR/clipse"
fi

# ── 3. config + theme ─────────────────────────────────────────────────────────
backup_if_real_file "$CFG_DIR/config.json"
backup_if_real_file "$CFG_DIR/custom_theme.json"
cp "$REPO_DIR/config.json"       "$CFG_DIR/config.json"
cp "$REPO_DIR/custom_theme.json" "$CFG_DIR/custom_theme.json"
echo "Installed clipse config + Catppuccin theme into $CFG_DIR"

# ── 4. popup launcher ─────────────────────────────────────────────────────────
install -m755 "$REPO_DIR/clipse-popup.sh" "$BIN_DIR/clipse-popup"
echo "Installed: $BIN_DIR/clipse-popup"

# ── 5. autostart the listener ─────────────────────────────────────────────────
cat > "$AUTOSTART_DIR/clipse.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=clipse clipboard listener
Comment=Records clipboard history for the clipse manager
Exec=$BIN_DIR/clipse --listen
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
echo "Installed autostart: $AUTOSTART_DIR/clipse.desktop"

# Start it now if not already running.
if ! pgrep -f "clipse --listen" >/dev/null 2>&1; then
    "$BIN_DIR/clipse" --listen >/dev/null 2>&1 &
    echo "Started clipse listener."
fi

# ── 6. GNOME Super+V hotkey ───────────────────────────────────────────────────
if command -v gsettings >/dev/null && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* || "${XDG_CURRENT_DESKTOP:-}" == *ubuntu* ]]; then
    # Free Super+V from the message tray (Super+M still toggles it).
    tray="$(gsettings get org.gnome.shell.keybindings toggle-message-tray 2>/dev/null || echo '')"
    if [[ "$tray" == *"<Super>v"* ]]; then
        gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>m']"
        echo "Freed Super+V from toggle-message-tray (Super+M still works)."
    fi

    # Register the custom keybinding (idempotent on the 'clipse' slot).
    base="org.gnome.settings-daemon.plugins.media-keys"
    slot="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/clipse/"
    existing="$(gsettings get $base custom-keybindings 2>/dev/null || echo '@as []')"
    if [[ "$existing" != *"$slot"* ]]; then
        if [[ "$existing" == "@as []" || "$existing" == "[]" ]]; then
            gsettings set $base custom-keybindings "['$slot']"
        else
            gsettings set $base custom-keybindings "${existing%]}, '$slot']"
        fi
    fi
    kb="$base.custom-keybinding:$slot"
    gsettings set "$kb" name 'Clipse clipboard history'
    gsettings set "$kb" command "$BIN_DIR/clipse-popup"
    gsettings set "$kb" binding '<Super>v'
    echo "Bound Super+V -> clipse-popup."
else
    echo "Not GNOME (or no gsettings) — bind a global shortcut to $BIN_DIR/clipse-popup yourself."
fi

# PATH sanity check.
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "Hint: add $BIN_DIR to your PATH (in ~/.bash_profile)." ;;
esac

cat <<'EOF'

Done. Clipboard history is live system-wide.
  • Global popup:   Super+V       (works in browser, GUI apps, anywhere)
  • Inside tmux:    prefix + y    (see anticrab.tmux)
  • Navigate:       j / k         Search: /     Choose: Enter (then Ctrl+V)
  • Delete: Backspace   Pin: p    Quit: Esc / q

Copies from password managers (1Password, Bitwarden, KeePassXC, …) are skipped.
EOF
