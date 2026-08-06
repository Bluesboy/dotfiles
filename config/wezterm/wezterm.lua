local wezterm = require("wezterm")
local nav = require("nav")
local plugins = require("plugins")
local config = wezterm.config_builder()
local act = wezterm.action

-- Appearance

config.color_scheme = "Catppuccin Macchiato"
config.font = wezterm.font("Ioskeley Mono Nerd Font", { weight = "Regular" })
config.font_size = 13.5
config.cell_width = 0.9

-- The tab bar itself is rendered by the tabline plugin, see plugins.lua.
config.enable_tab_bar = true

config.window_background_opacity = 0.90
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

-- Rendering
-- Wayland is disabled on purpose; run under XWayland with the OpenGL front end.

config.enable_wayland = false
config.front_end = "OpenGL"
config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

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
