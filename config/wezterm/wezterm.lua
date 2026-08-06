local wezterm = require("wezterm")
local nav = require("nav")
local plugins = require("plugins")
local config = wezterm.config_builder()
local act = wezterm.action

-- Appearance

config.color_scheme = "Catppuccin Macchiato"
config.font = wezterm.font("Ioskeley Mono Nerd Font", { weight = "Regular" })
config.font_size = 13.5

-- The tab bar itself is rendered by the tabline plugin, see plugins.lua.
config.enable_tab_bar = true

config.window_background_opacity = 0.95
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

-- Rendering

config.enable_wayland = true

-- Kept on OpenGL: WebGpu renders the subpixel-antialiased glyphs produced by
-- freetype_render_target below at a visibly different weight. Both back ends
-- report 96 dpi and both pick the discrete Radeon on their own, so the renderer
-- is the only difference that reaches the glyphs.
config.front_end = "OpenGL"

config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

-- Matches the 60 Hz panel. Anything above it renders frames the display never
-- shows, so raise this only to chase stutter, not for smoothness.
config.max_fps = 60

-- Terminal capabilities

-- wezterm ships its own terminfo, already installed system-wide. It advertises
-- undercurl and extended keys, which xterm-256color cannot describe.
-- tmux.conf must list the matching terminal-features: the outer TERM stops
-- matching its '*-256color:RGB' override, and truecolor would regress silently.
config.term = "wezterm"

-- tmux already runs extended-keys with the csi-u format; this closes the chain
-- so nvim can tell CTRL+I from Tab and CTRL+Enter from Enter.
config.enable_kitty_keyboard = true

-- Quality of life

-- wezterm is installed from pacman, so the built-in check only costs a network
-- request on every start and a notification nobody can act on.
config.check_for_updates = false

config.audible_bell = "Disabled"

config.window_close_confirmation = "NeverPrompt"

-- Nerd Font fallbacks routinely trip this and the popup interrupts typing.
config.warn_about_missing_glyphs = false

-- niri tiles windows, so a font size change must not try to resize the window.
config.adjust_window_size_when_changing_font_size = false

-- Only reached by panes without tmux, such as the toggle terminal; tmux keeps
-- its own history-limit of 100000.
config.scrollback_lines = 10000

-- Key bindings

config.keys = {
  -- paste from the clipboard
  { key = "V", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
  { key = "'", mods = "CTRL|SHIFT", action = act.Hide },
  { key = "t", mods = "SUPER", action = act.DisableDefaultAssignment },
  { key = "Enter", mods = "SHIFT", action = act.SendString("\x1b\r") },
}

-- Appends CTRL+hjkl and META+hjkl, see nav.lua.
nav.apply_to_config(config)

-- Plugins

plugins.apply_to_config(config)

return config
