#!/usr/bin/env bash
# Bootstrap: place wezterm.lua into the XDG config dir (~/.config/wezterm).
# Idempotent — safe to run repeatedly.
#
# Modes (mutually exclusive):
#   (default)   Copy wezterm.lua into ~/.config/wezterm/wezterm.lua.
#   --symlink   Symlink this repo's wezterm.lua into ~/.config/wezterm/wezterm.lua
#               (useful if you keep the repo at ~/projects/anticrab.wezterm and
#               want edits there to take effect immediately).
#
# In all modes an existing non-symlink wezterm.lua is moved to a timestamped
# backup before being replaced, so you never silently lose a hand-rolled config.

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET_DIR="$HOME/.config/wezterm"
TARGET_CONF="$TARGET_DIR/wezterm.lua"

MODE="copy"
for arg in "$@"; do
    case "$arg" in
        --symlink) MODE="symlink" ;;
        --copy)    MODE="copy" ;;
        -h|--help)
            cat <<EOF
Usage: install.sh [--symlink]

Without flags: copy wezterm.lua into ~/.config/wezterm/ (or skip if the repo is
already there). With --symlink: symlink instead — handy for hacking on the repo
from ~/projects/anticrab.wezterm.
EOF
            exit 0 ;;
        *) echo "Unknown argument: $arg (try --help)" >&2; exit 1 ;;
    esac
done

mkdir -p "$TARGET_DIR"

# Back up an existing $1 unless it's already the symlink we'd create — that way
# re-running the script doesn't litter the dir with .bak files.
backup_unless_already_correct() {
    local path="$1" want_target="$2"
    if [[ -L "$path" ]]; then
        local cur_target
        cur_target="$(readlink "$path")"
        if [[ "$cur_target" == "$want_target" ]]; then
            return 1  # already correct — caller should skip the recreate
        fi
    fi
    if [[ -e "$path" || -L "$path" ]]; then
        local backup="$path.bak.$(date +%Y%m%d-%H%M%S)"
        echo "Backing up existing $path -> $backup"
        mv "$path" "$backup"
    fi
    return 0
}

# wezterm.lua plus the Lua modules it requires. selection.lua has to sit next to
# it in ~/.config/wezterm, because that directory — not the repo — is what
# wezterm puts on package.path when the config is a symlink.
CONFIG_FILES=(wezterm.lua selection.lua)

place_file() {
    local name="$1" target="$TARGET_DIR/$1"
    if [[ "$MODE" == "symlink" ]]; then
        if backup_unless_already_correct "$target" "$REPO_DIR/$name"; then
            ln -sfn "$REPO_DIR/$name" "$target"
            echo "Linked: $target -> $REPO_DIR/$name"
        else
            echo "Skipped: $target already points to $REPO_DIR/$name"
        fi
    else
        if backup_unless_already_correct "$target" ""; then
            cp "$REPO_DIR/$name" "$target"
            echo "Copied: $REPO_DIR/$name -> $target"
        fi
    fi
}

if [[ "$REPO_DIR" == "$TARGET_DIR" ]]; then
    echo "Repo is already at $TARGET_DIR — config in place, nothing to do."
else
    for name in "${CONFIG_FILES[@]}"; do
        place_file "$name"
    done
fi

# Install the `wezterm` terminfo into ~/.terminfo so `config.term = "wezterm"`
# works and apps inside (tmux, nvim) get styled underlines (undercurl) + true
# colour. Bundled in the repo so this needs no network. Non-fatal if `tic` is
# missing — wezterm will just fall back to xterm-256color.
if command -v tic >/dev/null; then
    if ! infocmp -x wezterm >/dev/null 2>&1; then
        if tic -x -o "$HOME/.terminfo" "$REPO_DIR/wezterm.terminfo" 2>/dev/null; then
            echo "Installed terminfo: wezterm -> ~/.terminfo"
        else
            echo "Warning: failed to install wezterm terminfo (undercurl may not work)" >&2
        fi
    fi
else
    echo "Hint: 'tic' not found — install ncurses-bin to get the wezterm terminfo"
    echo "      (needed for undercurl / true colour inside tmux+nvim)."
fi

# Desktop integration: install the .desktop launcher + app icon so WezTerm shows
# up (with its logo, not a generic gear) in the GNOME app grid / dock. These live
# under ~/.local/share, which is easy to wipe by accident — bundling them here
# means one `install.sh` restores the icon. The launcher's Exec is pinned to the
# resolved wezterm binary so it works even if ~/.local/bin isn't on the session
# PATH. Non-fatal throughout.
DESKTOP_SRC="$REPO_DIR/desktop"
if [[ -d "$DESKTOP_SRC" ]]; then
    apps_dir="$HOME/.local/share/applications"
    icons_dir="$HOME/.local/share/icons/hicolor"
    mkdir -p "$apps_dir" "$icons_dir/128x128/apps" "$icons_dir/scalable/apps"

    # Resolve the wezterm binary for an absolute Exec/TryExec (fall back to the
    # bare name so the launcher is still valid if wezterm isn't installed yet).
    wez_bin="$(command -v wezterm || true)"
    [[ -n "$wez_bin" ]] || wez_bin="wezterm"
    desktop_out="$apps_dir/org.wezfurlong.wezterm.desktop"
    sed -e "s|^TryExec=.*|TryExec=$wez_bin|" \
        -e "s|^Exec=.*|Exec=$wez_bin start --cwd .|" \
        "$DESKTOP_SRC/wezterm.desktop" > "$desktop_out"
    chmod +x "$desktop_out"

    cp "$DESKTOP_SRC/org.wezfurlong.wezterm.png" "$icons_dir/128x128/apps/"
    cp "$DESKTOP_SRC/org.wezfurlong.wezterm.svg" "$icons_dir/scalable/apps/"

    # "Open with -> zvim": a launcher that opens files in nvim inside WezTerm.
    #
    # Needed because a `Terminal=true` entry (the one Neovim itself ships) is
    # handed to glib, which wraps it in a terminal from a hardcoded list headed
    # by gnome-terminal — update-alternatives' x-terminal-emulator is never
    # consulted. Our entry says Terminal=false and launches WezTerm itself.
    bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"
    install -m 755 "$DESKTOP_SRC/zvim-open" "$bin_dir/zvim-open"

    # Give it Neovim's own icon where one is installed, so the entry isn't
    # visually identical to the terminal. Falls back to WezTerm's logo.
    zvim_icon="org.wezfurlong.wezterm"
    for candidate in \
        /snap/nvim/current/usr/share/icons/hicolor/128x128/apps/nvim.png \
        /usr/share/icons/hicolor/128x128/apps/nvim.png \
        /usr/share/pixmaps/nvim.png
    do
        if [[ -f "$candidate" ]]; then
            cp "$candidate" "$icons_dir/128x128/apps/zvim.png"
            zvim_icon="zvim"
            break
        fi
    done

    zvim_out="$apps_dir/nvim-wezterm.desktop"
    sed -e "s|^TryExec=.*|TryExec=$bin_dir/zvim-open|" \
        -e "s|^Exec=.*|Exec=$bin_dir/zvim-open %F|" \
        -e "s|^Icon=.*|Icon=$zvim_icon|" \
        "$DESKTOP_SRC/nvim-wezterm.desktop" > "$zvim_out"
    chmod +x "$zvim_out"

    # Point the file associations at it. The user's mimeapps.list already named
    # nvim-wezterm.desktop and nvim.desktop, neither of which existed — which is
    # why files fell through to the system vim.desktop and opened in
    # gnome-terminal. text/plain is set outright because it pointed at draw.io,
    # whose own associations must stay put.
    mimeapps="$HOME/.config/mimeapps.list"
    if [[ -f "$mimeapps" ]]; then
        mime_backup="$mimeapps.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$mimeapps" "$mime_backup"
        "$DESKTOP_SRC/set-mimeapps" --file "$mimeapps" \
            --to nvim-wezterm.desktop \
            --from nvim.desktop --from nvim_nvim.desktop --from vim.desktop \
            --set text/plain=nvim-wezterm.desktop
        # Only keep the backup if something actually changed.
        if cmp -s "$mimeapps" "$mime_backup"; then
            rm -f "$mime_backup"
        else
            echo "Backed up existing $mimeapps -> $mime_backup"
        fi
    fi

    # Which terminal launches a `Terminal=true` entry. glib 2.80 ignores this
    # file (it has the hardcoded list instead), but xdg-terminal-exec and newer
    # glib read it, so setting it now means one less surprise later.
    echo "org.wezfurlong.wezterm.desktop" > "$HOME/.config/xdg-terminals.list"

    # Refresh the icon/desktop caches so the change shows without a relogin
    # (both are best-effort — GNOME picks the files up on next login regardless).
    command -v gtk-update-icon-cache >/dev/null && \
        gtk-update-icon-cache -f -t "$icons_dir" >/dev/null 2>&1 || true
    command -v update-desktop-database >/dev/null && \
        update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
    echo "Installed desktop launchers + icons (org.wezfurlong.wezterm, nvim-wezterm)."
fi

# WezTerm presence hint (non-fatal).
if ! command -v wezterm >/dev/null; then
    echo "Hint: WezTerm not found on PATH — install it from"
    echo "      https://wezfurlong.org/wezterm/installation"
fi

cat <<'EOF'

Done. WezTerm watches its config file and reloads on save, so changes apply to
open windows live — no restart needed.
EOF
