-- Tests for selection.lua — the clipboard cleaner used by wezterm's own
-- selection (Shift+drag and panes where nothing grabbed the mouse).
--
-- Run: nvim -l tests/selection_spec.lua          (from the repo root)
--
-- Plain asserts, no framework: this runs on whatever Lua is at hand, and the
-- repo has no other Lua tests to share a harness with.

package.path = "./?.lua;" .. package.path
local selection = require("selection")

local failures = 0
local checked = 0

local function shows(name, input, want)
    checked = checked + 1
    local got = selection.clean(input)
    if got ~= want then
        failures = failures + 1
        io.write(("FAIL %s\n  want %q\n  got  %q\n"):format(name, want, got))
    end
end

shows("strips trailing whitespace from every line", "alpha   \nbeta\t\n", "alpha\nbeta")

shows("turns whitespace-only lines into empty lines", "alpha\n    \nbeta\n", "alpha\n\nbeta")

shows("removes the indent shared by all lines", "  alpha\n  beta\n", "alpha\nbeta")

shows("keeps relative indentation", "  alpha\n      beta\n", "alpha\n    beta")

shows(
    "leaves a block that starts flush left alone",
    "def f():\n    return 1\n",
    "def f():\n    return 1"
)

shows("ignores blank lines when measuring the indent", "  alpha\n\n  beta\n", "alpha\n\nbeta")

shows("drops blank lines at both ends", "\n\nalpha\n\n\n", "alpha")

shows("drops the final newline so a pasted command is not run", "git status\n", "git status")

shows("keeps a single line as is", "git status", "git status")

shows("empty input gives empty output", "", "")

shows("whitespace-only input gives empty output", "   \n  \n", "")

if failures > 0 then
    io.write(("\n%d of %d checks failed\n"):format(failures, checked))
    os.exit(1)
end
io.write(("%d checks passed\n"):format(checked))
