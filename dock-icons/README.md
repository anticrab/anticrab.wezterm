# Dock icons (GNOME window ↔ .desktop matching)

Fixes apps that show a generic placeholder — or nothing at all — in the GNOME
dock and app switcher, while their icon file is installed and perfectly fine.

## Why it happens

The icon in the dock isn't read from the window. GNOME identifies a window by
its **Wayland `app_id`** (or X11 `WM_CLASS`), then maps that string to a
`.desktop` entry — first by scanning every entry for a matching
`StartupWMClass=`, then by looking for a file literally named
`<app_id>.desktop`. Miss both and the window has no app behind it, so there's no
`Icon=` to draw.

Two ways to miss:

**1. The entry is named differently from the `app_id`.** Qt's Wayland plugin
sends `QGuiApplication::desktopFileName()` when the app sets it, and the
**executable's basename** when it doesn't. Apps that never call
`setDesktopFileName()` therefore advertise their binary name, which reverse-DNS
entry filenames and renamed binaries both fail to match:

| App | `app_id` sent | Entry on disk |
|---|---|---|
| PlotJuggler | `plotjuggler` | `io.plotjuggler.PlotJuggler.desktop` |
| nekoray | `nekobox` | `nekoray.desktop` |

(PlotJuggler actually sets the reverse-DNS id as the window *title* instead —
visible in `WAYLAND_DEBUG=1` output. That's an upstream bug.)

**2. There's no host-side entry at all.** `rviz2` runs inside the ROS Docker
container; the Unity sim runs straight out of a build directory. Unity also sets
an *empty* `_NET_WM_ICON`, so GNOME has nothing to fall back on either.

Both cases are fixed by making some entry claim the `app_id` via
`StartupWMClass=`.

## Install

```bash
~/projects/anticrab.wezterm/dock-icons/install.sh
```

Idempotent. For PlotJuggler and nekoray it re-emits the **system** entry into
`~/.local/share/applications` with `StartupWMClass=` inserted — copied at install
time rather than vendored here, so a package update to `Exec`/`Name` isn't frozen
to whatever this repo last saw. For rviz2 and the Unity sim it installs the
entries and icons from [`entries/`](entries/) and [`icons/`](icons/); the Unity
one is skipped on machines without that build.

**Already-open windows keep the association GNOME cached when they were mapped**
— restart the app to see its icon. If an icon still doesn't appear, GNOME is
holding a stale icon theme; force a re-read without logging out:

```bash
gsettings set org.gnome.desktop.interface icon-theme Yaru
gsettings set org.gnome.desktop.interface icon-theme Yaru-purple
```

## Finding other offenders

```bash
./scan.py                      # audit installed entries + open X11 windows
./scan.py --check plotjuggler  # resolve an app_id the way gnome-shell does
./scan.py --probe plotjuggler  # launch it and read the app_id it really sends
```

The audit infers statically: for each Qt binary it checks the dynamic symbol
table for `setDesktopFileName`. Absent means the `app_id` is pinned to the
executable name, which is what separates a real mismatch (PlotJuggler) from a
false alarm (Wireshark — reverse-DNS entry name, but it *does* set the id, so
it's fine).

`--probe` is the ground truth: it runs the app under `WAYLAND_DEBUG=1` and reads
the `set_app_id(...)` call straight off the protocol.

## Notes

- Wayland-native windows can't be enumerated from outside — GNOME 46 blocks both
  `Shell.Eval` and `Shell.Introspect.GetWindows` (`AccessDenied`). So the audit
  covers installed entries and open X11/XWayland windows only; use `--probe` for
  anything else still showing a placeholder.
- Icons go into the hicolor directory matching their **actual pixel size**
  (`install.sh` reads it from the PNG header). A 256px file dropped into
  `128x128/apps` resolves but leaves the theme describing it at the wrong size.
- `rviz2.desktop` is `NoDisplay=true` — it's an icon carrier, not a launcher
  (its `Exec` is `/usr/bin/false`; rviz2 is started by the container's own
  `ros2 launch`). The Unity entry *is* a real launcher, so it stays visible.
