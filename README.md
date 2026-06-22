# anticrab.wezterm

Personal [WezTerm](https://wezfurlong.org/wezterm/) config. Companion to
[anticrab.nvim](https://github.com/anticrab/anticrab.nvim) and
[anticrab.tmux](https://github.com/anticrab/anticrab.tmux) — same Catppuccin /
JetBrainsMono look, meant to be driven with tmux inside.

Tested on Ubuntu 24.04 + GNOME Wayland.

## What's configured

- **Font** — JetBrainsMono Nerd Font, 12pt. Ligatures **off** (`==`, `!=`, `->`
  render as literal glyphs).
- **Theme** — Catppuccin Mocha (matches the nvim colorscheme).
- **No tab bar** — tmux already provides tabs/panes/status, so WezTerm's own bar
  is hidden.
- **Polish** — WebGpu renderer, `max_fps = 120`, audible bell off, steady block
  cursor, light background opacity (0.92), rounded padding.
- System title bar kept (`TITLE | RESIZE`); close confirmation disabled.

## Install

### TL;DR — two commands

```bash
# 1. Install WezTerm (apt often lacks it — see the link if so)
#    https://wezfurlong.org/wezterm/installation

# 2. Clone the repo and link the config into ~/.config/wezterm
git clone https://github.com/anticrab/anticrab.wezterm ~/projects/anticrab.wezterm \
    && ~/projects/anticrab.wezterm/install.sh --symlink
```

`install.sh` places `wezterm.lua` into `~/.config/wezterm/`. With `--symlink` it
symlinks this repo's file (edits go live); without flags it copies. An existing
`wezterm.lua` is backed up (timestamped) first. Idempotent — safe to re-run.

> WezTerm watches its config and reloads on save, so changes apply to open
> windows immediately — no restart needed.

## Notes

- If the WebGpu renderer glitches on your GPU/driver, set `front_end = "OpenGL"`
  in `wezterm.lua` (it's marked with a comment).
- Set your terminal font to a Nerd Font for icons (already JetBrainsMono here).
