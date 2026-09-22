#!/usr/bin/env python3
"""Tests for desktop/set-mimeapps — the mimeapps.list rewriter.

install.sh runs it to repoint file associations at the launcher that opens
files in WezTerm. The file belongs to the user and may hold anything, so the
rewriter has to touch only the entries it was told about and leave the rest
byte for byte alone.

Run: python3 -m unittest discover -s tests
"""

import pathlib
import subprocess
import tempfile
import unittest

SET_MIMEAPPS = pathlib.Path(__file__).resolve().parents[1] / "desktop" / "set-mimeapps"


class SetMimeapps(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = pathlib.Path(self.tmp.name) / "mimeapps.list"

    def rewrite(self, text, to="new.desktop", frm=("old.desktop",)):
        self.path.write_text(text)
        cmd = [str(SET_MIMEAPPS), "--file", str(self.path), "--to", to]
        for handler in frm:
            cmd += ["--from", handler]
        done = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        return self.path.read_text()

    # --- what it should change -------------------------------------------

    def test_replaces_a_stale_handler(self):
        out = self.rewrite("[Default Applications]\ntext/plain=old.desktop\n")
        self.assertEqual(out, "[Default Applications]\ntext/plain=new.desktop\n")

    def test_replaces_every_listed_stale_handler(self):
        out = self.rewrite(
            "[Default Applications]\ntext/plain=old.desktop\ntext/x-python=older.desktop\n",
            frm=("old.desktop", "older.desktop"),
        )
        self.assertEqual(
            out,
            "[Default Applications]\ntext/plain=new.desktop\ntext/x-python=new.desktop\n",
        )

    def test_replaces_the_stale_entry_inside_a_semicolon_list(self):
        out = self.rewrite("[Default Applications]\ntext/plain=keep.desktop;old.desktop;\n")
        self.assertEqual(
            out, "[Default Applications]\ntext/plain=keep.desktop;new.desktop;\n"
        )

    def test_does_not_duplicate_a_handler_already_in_the_list(self):
        out = self.rewrite("[Default Applications]\ntext/plain=old.desktop;new.desktop;\n")
        self.assertEqual(out, "[Default Applications]\ntext/plain=new.desktop;\n")

    # --- what it must not touch ------------------------------------------

    def test_leaves_other_handlers_alone(self):
        text = "[Default Applications]\ntext/html=firefox.desktop\n"
        self.assertEqual(self.rewrite(text), text)

    def test_leaves_other_sections_alone(self):
        text = (
            "[Default Applications]\ntext/plain=old.desktop\n"
            "\n[Added Associations]\ntext/plain=old.desktop;\n"
        )
        out = self.rewrite(text)
        self.assertIn("[Added Associations]\ntext/plain=old.desktop;\n", out)
        self.assertIn("[Default Applications]\ntext/plain=new.desktop\n", out)

    def test_keeps_comments_blank_lines_and_key_order(self):
        text = (
            "# hand written\n\n[Default Applications]\n"
            "x-scheme-handler/http=chrome.desktop\n"
            "text/plain=old.desktop\n"
            "# trailing note\n"
        )
        out = self.rewrite(text)
        self.assertEqual(
            out,
            "# hand written\n\n[Default Applications]\n"
            "x-scheme-handler/http=chrome.desktop\n"
            "text/plain=new.desktop\n"
            "# trailing note\n",
        )

    def test_file_without_a_default_applications_section_is_unchanged(self):
        text = "[Added Associations]\ntext/plain=old.desktop;\n"
        self.assertEqual(self.rewrite(text), text)

    # --- setting one association outright ---------------------------------

    def set_default(self, text, assignment):
        self.path.write_text(text)
        done = subprocess.run(
            [str(SET_MIMEAPPS), "--file", str(self.path), "--set", assignment],
            capture_output=True, text=True,
        )
        self.assertEqual(done.returncode, 0, done.stderr)
        return self.path.read_text()

    def test_set_replaces_whatever_handled_that_type(self):
        out = self.set_default(
            "[Default Applications]\ntext/plain=drawio.desktop\n",
            "text/plain=new.desktop",
        )
        self.assertEqual(out, "[Default Applications]\ntext/plain=new.desktop\n")

    def test_set_leaves_that_handler_alone_for_other_types(self):
        out = self.set_default(
            "[Default Applications]\nimage/svg+xml=drawio.desktop\n"
            "text/plain=drawio.desktop\n",
            "text/plain=new.desktop",
        )
        self.assertIn("image/svg+xml=drawio.desktop\n", out)
        self.assertIn("text/plain=new.desktop\n", out)

    def test_set_adds_the_type_when_it_is_missing(self):
        out = self.set_default(
            "[Default Applications]\ntext/html=firefox.desktop\n",
            "text/plain=new.desktop",
        )
        self.assertEqual(
            out,
            "[Default Applications]\ntext/html=firefox.desktop\ntext/plain=new.desktop\n",
        )

    def test_set_creates_the_section_when_the_file_has_none(self):
        out = self.set_default(
            "[Added Associations]\ntext/plain=old.desktop;\n",
            "text/plain=new.desktop",
        )
        self.assertIn("[Added Associations]\ntext/plain=old.desktop;\n", out)
        self.assertIn("[Default Applications]\ntext/plain=new.desktop\n", out)

    def test_set_is_idempotent(self):
        once = self.set_default(
            "[Default Applications]\ntext/plain=drawio.desktop\n",
            "text/plain=new.desktop",
        )
        twice = self.set_default(once, "text/plain=new.desktop")
        self.assertEqual(once, twice)

    # --- being run twice --------------------------------------------------

    def test_is_idempotent(self):
        once = self.rewrite("[Default Applications]\ntext/plain=old.desktop\n")
        twice = self.rewrite(once)
        self.assertEqual(once, twice)

    def test_missing_file_is_not_an_error(self):
        missing = pathlib.Path(self.tmp.name) / "absent.list"
        done = subprocess.run(
            [str(SET_MIMEAPPS), "--file", str(missing), "--to", "new.desktop",
             "--from", "old.desktop"],
            capture_output=True, text=True,
        )
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertFalse(missing.exists())


if __name__ == "__main__":
    unittest.main()
