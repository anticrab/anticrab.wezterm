# Clipboard history (clipse)

System-wide clipboard manager with searchable history, working uniformly across
WezTerm, tmux, nvim **and** GUI apps (browser, etc.) on GNOME Wayland.

## Why this exists

Two problems it solves:

1. **"Several clipboards" confusion.** On Wayland there are separate selections
   (PRIMARY = mouse-select, CLIPBOARD = explicit copy), and if `wl-clipboard`
   isn't installed the stack falls back to `xclip` (X11) — so half the tools
   write to the X11 clipboard and half to Wayland, kept loosely in sync by
   GNOME. Installing `wl-clipboard` puts everything on **one** Wayland CLIPBOARD.
2. **Only the last copy is available.** clipse records history so you can search
   and re-paste anything recent, not just the latest entry.

## How it works

- A listener daemon (`clipse --listen`, autostarted) watches the CLIPBOARD and
  records every copy from any app into `~/.config/clipse/clipboard_history.json`.
- A TUI picker shows the history. The daemon captures everything globally; the
  picker is just how you summon and choose.

## Usage

| Where | How to open |
|---|---|
| Anywhere (browser, GUI, …) | `Super+V` (floating WezTerm popup) |
| Inside tmux | `prefix + y` (centred tmux popup) |
| Any terminal | run `clipse` |

Inside the picker:

| Action | Key |
|---|---|
| Up / down | `k` / `j` |
| Search | `/` |
| Choose (copy + close) | `Enter` |
| Delete entry | `Backspace` |
| Pin / unpin | `p` |
| Preview | `Space` |
| Quit | `Esc` / `q` |

**Paste flow:** `Super+V → j/k or /search → Enter → Ctrl+V`. clipse copies the
chosen entry and closes; the actual paste is a normal `Ctrl+V` (GNOME Wayland
blocks synthetic keystrokes, so no manager can auto-paste reliably).

## Install

```bash
~/projects/anticrab.wezterm/clipboard/install.sh
```

Idempotent. Installs `wl-clipboard` (apt, asks for sudo), the pinned `clipse`
binary into `~/.local/bin`, the config + Catppuccin Mocha theme into
`~/.config/clipse`, an autostart entry for the listener, and the `Super+V`
GNOME shortcut (freeing it from `toggle-message-tray`, which keeps `Super+M`).

## Notes

- Copies from password managers (1Password, Bitwarden, KeePassXC, LastPass,
  Dashlane, …) are excluded from history — see `excludedApps` in `config.json`.
- History size is capped at `maxHistory` (250) entries.
- `autoPaste` is intentionally disabled (the `Enter → Ctrl+V` flow). Flip it in
  `config.json` only if you also set up `ydotool` for synthetic paste.
