#!/usr/bin/env python3
"""Find apps whose window won't match any .desktop entry (generic dock icon).

GNOME maps a window to an app by its Wayland app_id / X11 WM_CLASS: it checks
StartupWMClass= across all entries, then falls back to <app_id>.desktop. No hit
means no app association, and the dock draws the generic placeholder.

Modes:
  (default)          audit installed entries + currently-open X11 windows
  --check ID...      resolve IDs the way gnome-shell does (post-fix verification)
  --probe CMD...     launch CMD and report the app_id it actually sends

--probe is the ground truth; the audit is static inference. Qt apps that never
call QGuiApplication::setDesktopFileName() send their executable name as app_id,
and that call is visible in the dynamic symbol table — which is what lets the
audit tell a real mismatch (PlotJuggler) from a false alarm (Wireshark, which
does set it and is therefore fine despite a reverse-DNS entry name).
"""

import configparser
import glob
import os
import re
import shutil
import subprocess
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio  # noqa: E402

APP_DIRS = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/share/applications",
    "/usr/local/share/applications",
    "/var/lib/snapd/desktop/applications",
]

# Wrappers to look past when digging the real binary out of an Exec= line.
EXEC_NOISE = {"env", "sh", "bash", "-c", "flatpak", "snap", "run"}


def run(cmd, **kw):
    try:
        return subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=30, **kw
        ).stdout
    except Exception:
        return ""


def resolve(app_id):
    """gnome-shell's lookup order: StartupWMClass index, then <app_id>.desktop."""
    lc = app_id.lower()
    for info in Gio.DesktopAppInfo.get_all():
        try:
            wm = info.get_startup_wm_class()
        except Exception:
            wm = None
        if wm and wm.lower() == lc:
            return f"StartupWMClass -> {info.get_id()}"
    for candidate in (app_id + ".desktop", lc + ".desktop"):
        try:
            info = Gio.DesktopAppInfo.new(candidate)
        except TypeError:  # GLib raises rather than returning None
            info = None
        if info:
            return f"filename      -> {info.get_id()}"
    return None


def exec_binary(exec_line):
    if not exec_line:
        return None
    for token in exec_line.replace('"', " ").replace("'", " ").split():
        if token.startswith(("%", "-")) or "=" in token:
            continue
        base = os.path.basename(token)
        if base in EXEC_NOISE:
            continue
        if os.path.isabs(token) and os.path.exists(token):
            return token
        found = shutil.which(base)
        if found:
            return found
    return None


def qt_fallback_app_id(path):
    """app_id a Qt binary will send, or None if it isn't a Qt app / sets its own.

    Qt's Wayland plugin uses QGuiApplication::desktopFileName() when set and the
    executable's basename otherwise, so an absent setDesktopFileName import in
    the dynamic symbol table pins the app_id to the binary name.
    """
    headers = run(f"objdump -p {path!r} 2>/dev/null")
    if not re.search(r"NEEDED.*libQt\d?Gui", headers):
        return None
    if "setDesktopFileName" in run(f"objdump -T {path!r} 2>/dev/null"):
        return None
    return os.path.basename(path)


def load_entries():
    entries, seen = [], set()
    for directory in APP_DIRS:
        for path in sorted(glob.glob(directory + "/*.desktop")):
            entry_id = os.path.basename(path)[:-8]
            if entry_id in seen:  # earlier dirs win, as GLib does it
                continue
            seen.add(entry_id)
            parser = configparser.RawConfigParser(strict=False)
            parser.optionxform = str
            try:
                parser.read(path, encoding="utf-8")
            except Exception:
                continue
            if not parser.has_section("Desktop Entry"):
                continue
            section = parser["Desktop Entry"]
            if section.get("Type", "Application") != "Application":
                continue
            if section.get("Hidden", "").lower() == "true":
                continue
            entries.append((entry_id, section, path))
    return entries


def audit():
    problems = 0

    print("Installed entries whose Qt app_id won't match their filename:")
    for entry_id, section, path in load_entries():
        if section.get("StartupWMClass"):
            continue
        binary = exec_binary(section.get("Exec"))
        if not binary:
            continue
        app_id = qt_fallback_app_id(binary)
        if not app_id or app_id.lower() == entry_id.lower():
            continue
        if resolve(app_id):
            continue
        problems += 1
        print(f"  {section.get('Name', entry_id)}")
        print(f"      entry  : {path}")
        print(f"      app_id : {app_id}  (no {app_id}.desktop, no StartupWMClass match)")
    if not problems:
        print("  none")

    print("\nOpen X11/XWayland windows that match no entry:")
    unmatched = 0
    roots = run("xprop -root _NET_CLIENT_LIST 2>/dev/null")
    for wid in re.findall(r"0x[0-9a-f]+", roots):
        props = run(f"xprop -id {wid} WM_CLASS 2>/dev/null")
        classes = re.findall(r'"([^"]*)"', props)
        if not classes:
            continue
        # WM_CLASS is (instance, class); either may be what gnome-shell keys on.
        if any(resolve(c) for c in classes):
            continue
        unmatched += 1
        problems += 1
        print(f"  WM_CLASS={classes}  — no matching .desktop")
    if not unmatched:
        print("  none")

    print(
        "\nWayland-native windows can't be enumerated (GNOME 46 blocks Eval and"
        "\nShell.Introspect), so run --probe on anything still showing a"
        "\nplaceholder to read its app_id directly."
    )
    return 1 if problems else 0


def check(app_ids):
    bad = 0
    for app_id in app_ids:
        hit = resolve(app_id)
        if hit:
            print(f"  {app_id:22} OK       {hit}")
        else:
            bad += 1
            print(f"  {app_id:22} BROKEN   no entry — dock shows a placeholder")
    return 1 if bad else 0


def probe(argv):
    """Launch argv under WAYLAND_DEBUG and report the app_id it advertises."""
    env = dict(os.environ, WAYLAND_DEBUG="1")
    print(f"Launching {' '.join(argv)} — close its window when it appears.")
    try:
        proc = subprocess.run(
            argv, env=env, capture_output=True, text=True, timeout=120
        )
    except subprocess.TimeoutExpired as exc:
        proc = exc
    stream = (proc.stderr or "") + (proc.stdout or "")
    if isinstance(stream, bytes):
        stream = stream.decode("utf-8", "replace")
    ids = re.findall(r'set_app_id\("([^"]*)"\)', stream)
    if not ids:
        print("  no set_app_id seen — X11 app? use: xprop WM_CLASS")
        return 1
    for app_id in dict.fromkeys(ids):
        hit = resolve(app_id)
        print(f"  app_id={app_id!r}  ->  {hit or 'BROKEN: no matching .desktop'}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        sys.exit(check(sys.argv[2:]))
    if len(sys.argv) > 1 and sys.argv[1] == "--probe":
        sys.exit(probe(sys.argv[2:]))
    sys.exit(audit())
