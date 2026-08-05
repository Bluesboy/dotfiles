local wezterm = require("wezterm")
local plugins = require("plugins")
local config = wezterm.config_builder()
local act = wezterm.action

-- Helpers

local function is_vim(pane)
  return pane:get_user_vars().IS_NVIM == "true"
end

local direction_keys = {
  h = "Left",
  j = "Down",
  k = "Up",
  l = "Right",
}

local function split_nav(resize_or_move, key)
  return {
    key = key,
    mods = resize_or_move == "resize" and "META" or "CTRL",
    action = wezterm.action_callback(function(win, pane)
      if is_vim(pane) then
        -- pass the keys through to vim/nvim
        win:perform_action({
          SendKey = { key = key, mods = resize_or_move == "resize" and "META" or "CTRL" },
        }, pane)
      else
        if resize_or_move == "resize" then
          win:perform_action({ AdjustPaneSize = { direction_keys[key], 1 } }, pane)
        else
          win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
        end
      end
    end),
  }
end

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
  -- -- move between split panes
  -- split_nav("move", "h"),
  -- split_nav("move", "j"),
  -- split_nav("move", "k"),
  -- split_nav("move", "l"),
  --
  -- -- resize panes
  -- split_nav("resize", "h"),
  -- split_nav("resize", "j"),
  -- split_nav("resize", "k"),
  -- split_nav("resize", "l"),
}

-- Plugins

plugins.apply_to_config(config)

return config
