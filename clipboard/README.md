# Clipboard history (GPaste)

System-wide clipboard manager with searchable history, working across every app
— terminal (WezTerm/tmux/nvim), browser, GUI — on GNOME Wayland.

## Why GPaste (and not clipse / cliphist)

Terminal clipboard managers like clipse and cliphist record history through
`wl-paste --watch`, which relies on the **wlroots data-control protocol**.
GNOME's **Mutter compositor does not implement it**, so their listeners fail
with *"Watch mode requires a compositor that supports the wlroots data-control
protocol"* and never capture anything on GNOME.

GPaste is the native GNOME clipboard manager: it hooks GNOME's own clipboard
APIs, so it works reliably on Mutter — event-driven, no polling.

## Usage

- **`Super+V`** anywhere → history menu; **start typing to search**.
- Select an entry → it's copied to the clipboard → paste with `Ctrl+V`.
  (GNOME Wayland blocks synthetic keystrokes, so the final paste is manual.)
- Top-bar GPaste icon gives the same menu plus settings.

## Install

```bash
~/projects/anticrab.wezterm/clipboard/install.sh
```

Idempotent. Installs `gpaste-2` + `gnome-shell-extension-gpaste` (apt, asks for
sudo), applies settings (250-entry history, images on), binds `Super+V` to the
searchable history (freeing it from `toggle-message-tray`, which keeps
`Super+M`), and enables the Shell extension.

**Then log out and back in** — Wayland can't reload GNOME Shell live, so the
daemon + extension only start on a fresh session.

## Settings & portability

Key settings live in `org.gnome.GPaste` (gsettings/dconf). The installer sets
the important ones explicitly. To carry your own tweaks to a new machine:

```bash
dconf dump /org/gnome/GPaste/ > clipboard/gpaste-settings.dconf   # snapshot
dconf load /org/gnome/GPaste/ < clipboard/gpaste-settings.dconf   # restore
```

## Notes

- One Wayland CLIPBOARD across the whole stack — install `wl-clipboard` too
  (`sudo apt install wl-clipboard`) so tmux/nvim share it cleanly. tmux's config
  already prefers `wl-copy`; nvim's `unnamedplus` auto-detects `wl-paste`.
- GPaste excludes nothing by default; use its preferences to add password
  managers to the exclusion list if desired.
