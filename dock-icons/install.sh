#!/usr/bin/env bash
# Fix apps that show a generic placeholder icon in the GNOME dock.
#
# GNOME identifies a window by its Wayland app_id (or X11 WM_CLASS) and maps it
# to a .desktop file — first via a StartupWMClass= match, then by looking for
# <app_id>.desktop. When neither hits, the window can't be tied to an app entry
# and the dock draws the generic fallback icon. Two ways that happens:
#
#   1. The .desktop is named differently from the app_id. Qt apps that never
#      call QGuiApplication::setDesktopFileName() send their *executable name*
#      as app_id, which reverse-DNS entry names (io.plotjuggler.PlotJuggler)
#      and renamed binaries (nekoray.desktop -> nekobox) both miss.
#   2. There's no .desktop on this host at all (apps run from a container or a
#      raw build directory).
#
# Case 1 is fixed by re-emitting the *system* entry into ~/.local/share with a
# StartupWMClass= line — copied at install time rather than vendored, so a
# package update to Exec/Name isn't frozen to whatever this repo last saw.
# Case 2 is fixed with the NoDisplay entries + icons under entries/ and icons/.
#
# Idempotent — safe to re-run. Run ./scan.py to find further offenders.

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/hicolor"

mkdir -p "$APPS_DIR" "$ICONS_DIR/128x128/apps"

# Re-emit a system .desktop into ~/.local/share with StartupWMClass set.
# The line is inserted directly after [Desktop Entry] — appending would land it
# in a trailing [Desktop Action …] group, where it has no effect.
patch_system_entry() {
    local id="$1" wmclass="$2"
    local src="/usr/share/applications/$id.desktop"

    if [[ ! -f "$src" ]]; then
        echo "  skip: $id — not installed on this machine"
        return 0
    fi

    local out="$APPS_DIR/$id.desktop"
    awk -v wm="$wmclass" '
        /^StartupWMClass=/ { next }
        { print }
        /^\[Desktop Entry\][[:space:]]*$/ && !seen { print "StartupWMClass=" wm; seen = 1 }
    ' "$src" > "$out.tmp"

    # Only touch the real file when the content changed, so re-runs are quiet
    # and GNOME doesn't see a pointless modification event.
    if [[ -f "$out" ]] && cmp -s "$out.tmp" "$out"; then
        rm -f "$out.tmp"
        echo "  ok:   $id — already patched (StartupWMClass=$wmclass)"
    else
        mv "$out.tmp" "$out"
        echo "  set:  $id — StartupWMClass=$wmclass"
    fi
}

echo "Patching system entries whose app_id doesn't match their filename:"
# PlotJuggler: entry is io.plotjuggler.PlotJuggler.desktop, but the binary sends
# app_id "plotjuggler" (verified with WAYLAND_DEBUG=1 — it sets the reverse-DNS
# id as the window *title* instead, which is upstream's bug).
patch_system_entry "io.plotjuggler.PlotJuggler" "plotjuggler"
# nekoray: entry is nekoray.desktop, binary is /opt/nekoray/nekobox.
patch_system_entry "nekoray" "nekobox"

echo "Installing standalone entries for apps with no host .desktop:"

# Reads the entry body from stdin. Buffers it first: comparing straight from
# /dev/stdin would consume the stream, leaving nothing to write on a mismatch.
install_entry() {
    local name="$1"
    local out="$APPS_DIR/$name.desktop"
    cat > "$out.tmp"
    if [[ -f "$out" ]] && cmp -s "$out.tmp" "$out"; then
        rm -f "$out.tmp"
        echo "  ok:   $name — unchanged"
    else
        mv "$out.tmp" "$out"
        echo "  set:  $name"
    fi
}

# Install a PNG under the hicolor dir matching its actual pixel size. Dropping a
# 256px file into 128x128/apps mostly works but leaves the theme describing the
# icon at the wrong size, which is exactly the kind of mismatch that renders as
# a blank slot — so place it honestly instead.
install_icon() {
    local src="$1"
    # Width sits at bytes 16..19 of a PNG (IHDR); read it with the stdlib rather
    # than Pillow, which isn't guaranteed on a fresh machine. 128 is a safe
    # guess if the read fails — a wrong dir still resolves, just less precisely.
    local size
    size="$(python3 -c "
import struct, sys
with open(sys.argv[1], 'rb') as fh:
    fh.read(16)
    print(struct.unpack('>I', fh.read(4))[0])
" "$src" 2>/dev/null || echo 128)"
    local dir="$ICONS_DIR/${size}x${size}/apps"
    mkdir -p "$dir"
    cp "$src" "$dir/$(basename "$src")"
}

# rviz2 — always installed; the icon is useful whenever the ROS container runs.
install_entry "rviz2" < "$REPO_DIR/entries/rviz2.desktop"
install_icon "$REPO_DIR/icons/rviz2.png"

# Unity sim — machine-specific dev build; install only where it actually exists.
UNITY_BUILD="$HOME/projects/unity-sim/build/linux/Unity_Simulation"
UNITY_CWD="$HOME/projects/unity-sim"
if [[ -x "$UNITY_BUILD" ]]; then
    sed -e "s|@BUILD@|$UNITY_BUILD|" -e "s|@BUILDDIR@|$UNITY_CWD|" \
        "$REPO_DIR/entries/unity-simulation.desktop" \
        | install_entry "unity-simulation"
    install_icon "$REPO_DIR/icons/unity-simulation.png"
else
    echo "  skip: unity-simulation — no build at $UNITY_BUILD"
fi

# Refresh caches so icons appear without a relogin (best-effort: GNOME rescans
# both dirs on next login anyway).
command -v gtk-update-icon-cache >/dev/null && \
    gtk-update-icon-cache -f -t "$ICONS_DIR" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null && \
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true

cat <<'EOF'

Done. Already-open windows keep the app association GNOME cached when they were
mapped — restart those apps to see the corrected icon.

Check the result with:  ./scan.py --check plotjuggler nekobox rviz2 Unity_Simulation
EOF
