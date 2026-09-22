# anticrab.wezterm

Personal [WezTerm](https://wezfurlong.org/wezterm/) config. Companion to
[anticrab.nvim](https://github.com/anticrab/anticrab.nvim) and
[anticrab.tmux](https://github.com/anticrab/anticrab.tmux) — same JetBrains Dark /
JetBrainsMono look, meant to be driven with tmux inside.

Tested on Ubuntu 24.04 + GNOME Wayland.

## What's configured

- **Starts in tmux** — `default_prog` runs `tmux new -A -s main`, so opening a
  window attaches straight to the `main` session (created on first launch).
- **Font** — JetBrainsMono Nerd Font, 12pt. Ligatures **off** (`==`, `!=`, `->`
  render as literal glyphs).
- **Theme** — JetBrains "Dark", the CLion New UI scheme: `#1e1f22` background,
  `#bcbec4` text, `#214283` selection, taken from JetBrains' own scheme files.
  tmux and zvim (`jb.nvim`) carry the same palette, so the three layers read as
  one program. The 16 ANSI colours are JetBrains' terminal ones with two fixes:
  black isn't the background colour, and cyan is the scheme's teal rather than a
  second blue.
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
- **Selection** — a drag copies on release and the selection stays visible;
  double-click takes a whole path, URL, `file.cpp:42` or `user@host` (same word
  boundaries as tmux); triple-click takes the line. What lands on the clipboard
  is cleaned first — see below.
- **Polish** — WebGpu renderer, `max_fps = 120`, audible bell off, steady block
  cursor, light background opacity (0.92), rounded padding.
- System title bar kept (`TITLE | RESIZE`); close confirmation disabled.

## Selecting and copying

tmux owns the mouse inside a pane, so WezTerm's own selection is what you get
with **Shift+drag** (Shift is `bypass_mouse_reporting_modifiers`), or in any pane
where nothing grabbed the mouse.

Those selections go through [`selection.lua`](selection.lua) before reaching the
clipboard. TUI programs paint a left margin around their output, so a selection
copied verbatim pastes with leading spaces on every line; the filter drops the
trailing padding, the indent shared by every line, blank lines at the ends and
the final newline (so a pasted command doesn't run on its own). Relative
indentation survives, so a copied function keeps its shape.

```bash
nvim -l tests/selection_spec.lua     # tests for the filter
```

Where the selection belongs to a program inside, that program cleans it:
[anticrab.tmux](https://github.com/anticrab/anticrab.tmux) filters copy-mode
selections (and, knowing which column a drag started at, handles an indented
block selected from its first character), zvim copies buffer text on mouse
release, and Claude Code already copies clean text.

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

A system-wide clipboard manager (GPaste) with searchable history, working
across WezTerm, tmux, nvim **and** GUI apps (browser) — `Super+V` anywhere.
GPaste is used because GNOME/Mutter doesn't support the wlroots data-control
protocol that terminal managers (clipse/cliphist) need. Set up via
[`clipboard/install.sh`](clipboard/); details in
[`clipboard/README.md`](clipboard/README.md).

## Dock icons

Some apps show a generic placeholder in the GNOME dock even though their icon is
installed — GNOME matches a window to a `.desktop` entry by its Wayland `app_id`,
and Qt apps that don't set one advertise their *binary* name instead
(`io.plotjuggler.PlotJuggler.desktop` vs `app_id=plotjuggler`). Others ship no
host entry at all because they run from a container or a build dir.
[`dock-icons/install.sh`](dock-icons/) fixes the local offenders and
[`dock-icons/scan.py`](dock-icons/scan.py) finds new ones; details in
[`dock-icons/README.md`](dock-icons/README.md).

## Install

### TL;DR — two commands

```bash
# 1. Install WezTerm (apt often lacks it — see the link if so)
#    https://wezfurlong.org/wezterm/installation

# 2. Clone the repo and link the config into ~/.config/wezterm
git clone https://github.com/anticrab/anticrab.wezterm ~/projects/anticrab.wezterm \
    && ~/projects/anticrab.wezterm/install.sh --symlink
```

`install.sh` places `wezterm.lua` and `selection.lua` into `~/.config/wezterm/`
and installs the bundled `wezterm.terminfo` into `~/.terminfo` (via `tic -x`,
needed for `term = "wezterm"` / undercurl). Both Lua files have to sit in that
directory, because it — not the repo — is what WezTerm puts on `package.path`
when the config is a symlink. With `--symlink` it symlinks this repo's files
(edits go live); without flags it copies. Existing files are backed up
(timestamped) first. Idempotent — safe to re-run.

It also installs the **desktop launcher + app icon** from [`desktop/`](desktop/)
into `~/.local/share` (`org.wezfurlong.wezterm.{desktop,png,svg}`), so WezTerm
shows up with its real logo in the GNOME app grid / dock instead of a generic
icon. The launcher's `Exec` is pinned to the resolved `wezterm` binary. (These
files are bundled here precisely because `~/.local/share` is easy to wipe by
accident — one re-run restores the icon.)

> WezTerm watches its config and reloads on save, so changes apply to open
> windows immediately — no restart needed.

## Notes

- If the WebGpu renderer glitches on your GPU/driver, set `front_end = "OpenGL"`
  in `wezterm.lua` (it's marked with a comment).
- Set your terminal font to a Nerd Font for icons (already JetBrainsMono here).
