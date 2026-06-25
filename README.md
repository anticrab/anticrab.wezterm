# anticrab.wezterm

Personal [WezTerm](https://wezfurlong.org/wezterm/) config. Companion to
[anticrab.nvim](https://github.com/anticrab/anticrab.nvim) and
[anticrab.tmux](https://github.com/anticrab/anticrab.tmux) — same Catppuccin /
JetBrainsMono look, meant to be driven with tmux inside.

Tested on Ubuntu 24.04 + GNOME Wayland.

## What's configured

- **Starts in tmux** — `default_prog` runs `tmux new -A -s main`, so opening a
  window attaches straight to the `main` session (created on first launch).
- **Font** — JetBrainsMono Nerd Font, 12pt. Ligatures **off** (`==`, `!=`, `->`
  render as literal glyphs).
- **Theme** — Catppuccin Mocha (matches the nvim colorscheme).
- **No tab bar** — tmux already provides tabs/panes/status, so WezTerm's own bar
  is hidden.
- **`term = "wezterm"`** — advertises the wezterm terminfo (installed by
  `install.sh`), enabling styled underlines (coloured LSP undercurls in nvim)
  and true colour through tmux.
- **Clickable hyperlinks** — built-in URL rules plus bare `www.` domains;
  Ctrl+click opens. Auto-linkifies on-screen text, so links work even inside
  tmux/nvim. (Needs `terminal-features … hyperlinks` in
  [anticrab.tmux](https://github.com/anticrab/anticrab.tmux) for OSC 8 links
  emitted by programs.)
- **Polish** — WebGpu renderer, `max_fps = 120`, audible bell off, steady block
  cursor, light background opacity (0.92), rounded padding.
- System title bar kept (`TITLE | RESIZE`); close confirmation disabled.

## Keybindings

Host-level bindings use `CTRL+SHIFT` (GNOME Wayland grabs `SUPER`), and don't
clash with tmux's `C-a` prefix:

| Keys | Action |
|---|---|
| `CTRL+SHIFT+O` | Toggle background transparency (0.92 ↔ opaque) |
| `CTRL+SHIFT+L` | Open a URL on screen via keyboard (quick-select) |
| `CTRL+SHIFT+Space` | Quick-select (copy paths/hashes/URLs, no mouse) |
| `CTRL+SHIFT+U` | Unicode / emoji picker (CharSelect) |
| `CTRL+SHIFT+P` | Command palette |
| `CTRL` `+` / `-` / `0` | Font size up / down / reset |

## Clipboard history

A system-wide clipboard manager (clipse) with searchable history, working
across WezTerm, tmux, nvim **and** GUI apps (browser) — `Super+V` anywhere,
`prefix + y` in tmux. Set up via [`clipboard/install.sh`](clipboard/); details
in [`clipboard/README.md`](clipboard/README.md).

## Install

### TL;DR — two commands

```bash
# 1. Install WezTerm (apt often lacks it — see the link if so)
#    https://wezfurlong.org/wezterm/installation

# 2. Clone the repo and link the config into ~/.config/wezterm
git clone https://github.com/anticrab/anticrab.wezterm ~/projects/anticrab.wezterm \
    && ~/projects/anticrab.wezterm/install.sh --symlink
```

`install.sh` places `wezterm.lua` into `~/.config/wezterm/` and installs the
bundled `wezterm.terminfo` into `~/.terminfo` (via `tic -x`, needed for
`term = "wezterm"` / undercurl). With `--symlink` it symlinks this repo's config
(edits go live); without flags it copies. An existing `wezterm.lua` is backed up
(timestamped) first. Idempotent — safe to re-run.

> WezTerm watches its config and reloads on save, so changes apply to open
> windows immediately — no restart needed.

## Notes

- If the WebGpu renderer glitches on your GPU/driver, set `front_end = "OpenGL"`
  in `wezterm.lua` (it's marked with a comment).
- Set your terminal font to a Nerd Font for icons (already JetBrainsMono here).
