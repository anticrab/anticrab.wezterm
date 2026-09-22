#!/usr/bin/env python3
"""Tests for desktop/zvim-open — the launcher behind nvim-wezterm.desktop.

GNOME hands a file manager's "open with" an absolute path and no working
directory, so a bare `nvim %F` would start with the cwd wherever the session
happened to be. This wrapper picks the file's own directory instead, which is
what telescope, live_grep and auto-session key off.

`wezterm` is replaced by a stub on PATH that records its argv, so the test
exercises the real script without opening a window.

Run: python3 -m unittest discover -s tests
"""

import os
import pathlib
import subprocess
import tempfile
import unittest

ZVIM_OPEN = pathlib.Path(__file__).resolve().parents[1] / "desktop" / "zvim-open"

STUB = """#!/bin/sh
printf '%s\\n' "$@" > "$RECORD"
"""


class ZvimOpen(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.record = self.root / "argv"

        stub = self.bin / "wezterm"
        stub.write_text(STUB)
        stub.chmod(0o755)

    def run_open(self, *args, cwd=None):
        env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                   RECORD=str(self.record))
        done = subprocess.run([str(ZVIM_OPEN), *args], capture_output=True,
                              text=True, env=env, cwd=cwd or self.root)
        self.assertEqual(done.returncode, 0, done.stderr)
        return self.record.read_text().splitlines()

    def make_file(self, relative):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("")
        return path

    # --- the working directory -------------------------------------------

    def test_starts_in_the_directory_of_the_file(self):
        target = self.make_file("project/src/main.cpp")
        argv = self.run_open(str(target))
        self.assertIn("--cwd", argv)
        self.assertEqual(argv[argv.index("--cwd") + 1], str(target.parent))

    def test_resolves_a_relative_path_to_an_absolute_directory(self):
        self.make_file("project/src/main.cpp")
        argv = self.run_open("project/src/main.cpp")
        self.assertEqual(
            argv[argv.index("--cwd") + 1], str(self.root / "project" / "src")
        )

    def test_a_directory_argument_is_used_as_the_working_directory(self):
        target = self.root / "project"
        target.mkdir()
        argv = self.run_open(str(target))
        self.assertEqual(argv[argv.index("--cwd") + 1], str(target))

    def test_without_arguments_no_working_directory_is_forced(self):
        argv = self.run_open()
        self.assertNotIn("--cwd", argv)

    def test_a_path_that_does_not_exist_does_not_force_a_working_directory(self):
        argv = self.run_open(str(self.root / "gone" / "missing.txt"))
        self.assertNotIn("--cwd", argv)

    # --- what gets launched ----------------------------------------------

    def test_launches_nvim_inside_wezterm(self):
        target = self.make_file("notes.md")
        argv = self.run_open(str(target))
        self.assertEqual(argv[0], "start")
        self.assertIn("--", argv)
        self.assertEqual(argv[argv.index("--") + 1], "nvim")

    def test_passes_every_file_through_to_nvim(self):
        first = self.make_file("project/a.txt")
        second = self.make_file("project/b.txt")
        argv = self.run_open(str(first), str(second))
        self.assertEqual(argv[argv.index("--") + 1:], ["nvim", str(first), str(second)])

    def test_keeps_a_filename_with_spaces_as_one_argument(self):
        target = self.make_file("project/two words.txt")
        argv = self.run_open(str(target))
        self.assertEqual(argv[-1], str(target))

    def test_without_arguments_still_opens_nvim(self):
        argv = self.run_open()
        self.assertEqual(argv[argv.index("--") + 1:], ["nvim"])


if __name__ == "__main__":
    unittest.main()
