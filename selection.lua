-- Clean up a selection before it reaches the clipboard.
--
-- TUI programs paint a left margin around their output, so a selection copied
-- verbatim pastes with leading spaces on every line. This trims that noise while
-- keeping the text — and the *relative* indentation of code:
--
--   * trailing whitespace goes, whitespace-only lines become empty lines
--   * the indent shared by every line goes
--   * blank lines at both ends go
--   * the final newline goes, so a pasted command doesn't run on its own
--
-- Used by wezterm.lua for wezterm's own selection (Shift+drag, or a pane where
-- nothing grabbed the mouse). anticrab.tmux's scripts/clean-copy does the same
-- for selections made inside tmux, and can do one thing more: tmux tells it
-- which column the drag started at, so it can spot a drag that began on the
-- first character of an indented block. wezterm exposes no such thing, so here
-- that block looks like it starts flush left and its indent is left as is.
--
-- Tests: nvim -l tests/selection_spec.lua

local M = {}

function M.clean(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, (line:gsub("%s+$", "")))
    end

    while #lines > 0 and lines[1] == "" do
        table.remove(lines, 1)
    end
    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end

    local cut
    for _, line in ipairs(lines) do
        if line ~= "" then
            local indent = #line:match("^ *")
            if cut == nil or indent < cut then
                cut = indent
            end
        end
    end

    if cut and cut > 0 then
        for index, line in ipairs(lines) do
            if line ~= "" then
                lines[index] = line:sub(cut + 1)
            end
        end
    end

    return table.concat(lines, "\n")
end

return M
