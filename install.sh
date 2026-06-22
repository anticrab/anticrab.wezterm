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

if [[ "$REPO_DIR" == "$TARGET_DIR" ]]; then
    echo "Repo is already at $TARGET_DIR — config in place, nothing to do."
elif [[ "$MODE" == "symlink" ]]; then
    if backup_unless_already_correct "$TARGET_CONF" "$REPO_DIR/wezterm.lua"; then
        ln -sfn "$REPO_DIR/wezterm.lua" "$TARGET_CONF"
        echo "Linked: $TARGET_CONF -> $REPO_DIR/wezterm.lua"
    else
        echo "Skipped: $TARGET_CONF already points to $REPO_DIR/wezterm.lua"
    fi
else
    if backup_unless_already_correct "$TARGET_CONF" ""; then
        cp "$REPO_DIR/wezterm.lua" "$TARGET_CONF"
        echo "Copied: $REPO_DIR/wezterm.lua -> $TARGET_CONF"
    fi
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

# WezTerm presence hint (non-fatal).
if ! command -v wezterm >/dev/null; then
    echo "Hint: WezTerm not found on PATH — install it from"
    echo "      https://wezfurlong.org/wezterm/installation"
fi

cat <<'EOF'

Done. WezTerm watches its config file and reloads on save, so changes apply to
open windows live — no restart needed.
EOF
