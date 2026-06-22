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

-- Colors — match the nvim catppuccin theme.
config.color_scheme = "Catppuccin Mocha"

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
