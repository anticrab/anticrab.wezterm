local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- Launch straight into tmux: attach to session "main" (create it if missing).
-- tmux is the primary driver here, so a wezterm window === the main session.
-- `-l` makes bash a login shell so ~/.bash_profile is sourced first.
config.default_prog = { "bash", "-l", "-c", "tmux new -A -s main" }

-- Advertise the `wezterm` terminfo (installed by install.sh into ~/.terminfo).
-- Gives apps inside — tmux, nvim — styled underlines (undercurl) and proper
-- true colour. Falls back gracefully if the terminfo isn't present.
config.term = "wezterm"

-- Font
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 12.0
-- Disable ligatures (calt/clig/liga) so ==, !=, -> render as literal glyphs.
config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }

-- Colors — JetBrains "Dark" (the CLion New UI scheme) ─────────────────────────
-- Editor colours come from JetBrains' own scheme (intellij-community's
-- expUI_darkScheme.xml); the greys and the accent blue from the New UI theme
-- palette. tmux (anticrab.tmux) and zvim (jb.nvim in anticrab.nvim) use the very
-- same values, so the three layers read as one program:
--   #1e1f22 editor bg   #2b2d30 panels   #43454a raised   #393b40 separators
--   #bcbec4 text        #9da0a8 dim      #6f737a dimmer   #dfe1e5 bright
--   #3574f0 accent      #214283 selection
--
-- The 16 ANSI slots are JetBrains' terminal colours with two fixes: black isn't
-- the background colour (it would be invisible), and cyan is the scheme's teal
-- instead of a second blue.
config.colors = {
    foreground = "#bcbec4",
    background = "#1e1f22",

    cursor_bg = "#ced0d6",
    cursor_fg = "#1e1f22",
    cursor_border = "#ced0d6",

    -- "none" keeps each glyph's own colour under the selection, the way the
    -- IDE does, instead of repainting the text in one flat colour.
    selection_bg = "#214283",
    selection_fg = "none",

    split = "#393b40",
    scrollbar_thumb = "#43454a",

    ansi = { "#43454a", "#f75464", "#6aab73", "#fbc36c", "#57a8f5", "#c87dbb", "#2aacb8", "#bcbec4" },
    brights = { "#6f737a", "#ff6b68", "#73bd79", "#f2c55c", "#83acfc", "#dba4d0", "#42b1a4", "#dfe1e5" },
}

-- Стандартная системная рамка с заголовком и кнопками
config.window_decorations = "TITLE | RESIZE"

-- Лёгкая прозрачность фона
config.window_background_opacity = 0.92

config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }

-- No wezterm tab bar — tmux already provides tabs/panes/status.
config.enable_tab_bar = false

-- Rendering / polish
config.front_end = "WebGpu"        -- smoother GPU rendering (set to "OpenGL" if anything glitches)
config.max_fps = 120
config.animation_fps = 60
config.audible_bell = "Disabled"   -- no terminal beep
config.default_cursor_style = "SteadyBlock"

config.scrollback_lines = 10000
config.window_close_confirmation = "NeverPrompt"

-- Clickable hyperlinks ────────────────────────────────────────────────────────
-- Keep wezterm's built-in rules (http/https/mailto/file://) and add bare
-- www. domains. Ctrl+click opens; this auto-linkifies the on-screen text, so
-- it works even when the link is shown *inside* tmux or nvim. OSC 8 hyperlinks
-- emitted by programs (ls --hyperlink, gh, compilers) also need tmux to pass
-- them through — see the `terminal-features ... hyperlinks` line in tmux.conf.
config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
    regex = [[\bwww\.[\w.-]+\.[a-z]{2,}\S*\b]],
    format = "https://$0",
})

-- Selection ───────────────────────────────────────────────────────────────────
-- Word boundaries for double-click. Same set as tmux's `word-separators`, so
-- ~/projects/foo-bar.lua, https://…, file.cpp:42 and user@host come out whole
-- in either layer (wezterm's default list already does this; tmux's did not).
config.selection_word_boundary = " \t\n{}[]()\"'`,;<>|"

-- Cleaning a selection before it reaches the clipboard: selection.lua drops the
-- trailing padding, the shared left margin, the blank lines at the ends and the
-- final newline that TUI programs leave in a copied screen. Same treatment as
-- tmux's scripts/copy-selection (see selection.lua for the one difference).
-- install.sh puts selection.lua next to this file; look for it there explicitly
-- rather than trusting the default search paths.
package.path = wezterm.config_dir .. "/?.lua;" .. package.path
local selection = require("selection")

local function copy_cleaned_selection(window, pane)
    local text = window:get_selection_text_for_pane(pane)
    if text and text ~= "" then
        window:copy_to_clipboard(selection.clean(text), "ClipboardAndPrimarySelection")
        return true
    end
    return false
end

-- tmux owns the mouse inside a pane, so these fire when the selection belongs to
-- wezterm: Shift+drag (SHIFT is `bypass_mouse_reporting_modifiers`, and wezterm
-- then matches bindings as if SHIFT weren't held — hence mods = "NONE"), or in
-- any pane where nothing grabbed the mouse. Merged with the defaults, so every
-- other gesture keeps working.
config.mouse_bindings = {
    {
        -- Release after a drag: copy the cleaned selection. With no selection
        -- this was a plain click, so follow a link if one is under the cursor —
        -- the behaviour the default binding bundles into one action.
        event = { Up = { streak = 1, button = "Left" } },
        mods = "NONE",
        action = wezterm.action_callback(function(window, pane)
            if not copy_cleaned_selection(window, pane) then
                window:perform_action(act.OpenLinkAtMouseCursor, pane)
            end
        end),
    },
    {
        -- Double-click: the word (path, URL, user@host) under the cursor.
        event = { Up = { streak = 2, button = "Left" } },
        mods = "NONE",
        action = wezterm.action_callback(copy_cleaned_selection),
    },
    {
        -- Triple-click: the whole line.
        event = { Up = { streak = 3, button = "Left" } },
        mods = "NONE",
        action = wezterm.action_callback(copy_cleaned_selection),
    },
}

-- Host-level keybindings ───────────────────────────────────────────────────────
-- Use CTRL+SHIFT (not SUPER): GNOME Wayland grabs SUPER for the Activities
-- overview, which would swallow the bindings. These don't clash with tmux's
-- C-a prefix. Font size (CTRL +/-/0), command palette (CTRL+SHIFT+P),
-- quick-select (CTRL+SHIFT+Space) and CharSelect (CTRL+SHIFT+U) are wezterm
-- defaults and stay as-is.
config.keys = {
    -- Toggle background transparency on the fly.
    {
        key = "o",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window)
            local overrides = window:get_config_overrides() or {}
            if overrides.window_background_opacity == 1.0 then
                overrides.window_background_opacity = 0.92
            else
                overrides.window_background_opacity = 1.0
            end
            window:set_config_overrides(overrides)
        end),
    },
    -- Open a URL on screen using the keyboard (no mouse): highlights URLs,
    -- type the label, the link opens in the browser. Works inside tmux/nvim.
    {
        key = "l",
        mods = "CTRL|SHIFT",
        action = act.QuickSelectArgs({
            label = "open url",
            patterns = { "https?://\\S+", "www\\.\\S+" },
            action = wezterm.action_callback(function(window, pane)
                local url = window:get_selection_text_for_pane(pane)
                if url and url ~= "" then
                    if not url:match("^https?://") then
                        url = "https://" .. url
                    end
                    wezterm.open_with(url)
                end
            end),
        }),
    },
}

return config
