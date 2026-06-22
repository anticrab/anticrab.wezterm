local wezterm = require("wezterm")
local config = wezterm.config_builder()

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

return config
