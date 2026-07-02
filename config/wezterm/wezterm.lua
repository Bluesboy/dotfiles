local wezterm = require("wezterm")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
local toggle_terminal = wezterm.plugin.require("https://github.com/zsh-sage/toggle_terminal.wez")
local config = wezterm.config_builder()
local act = wezterm.action

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

config.color_scheme = "Catppuccin Macchiato"
config.font = wezterm.font("Ioskeley Mono Nerd Font", {
  weight = "Regular",
  undo,
})
config.font_size = 13.5

config.enable_tab_bar = true

config.enable_wayland = false

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
config.debug_key_events = true

config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

config.window_background_opacity = 0.90

config.cell_width = 0.9

config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}

config.front_end = "OpenGL"

tabline.setup({
  options = {
    icons_enabled = true,
    theme = "Catppuccin Macchiato",
    tabs_enabled = true,
    theme_overrides = {},
    section_separators = {
      left = wezterm.nerdfonts.pl_left_hard_divider,
      right = wezterm.nerdfonts.pl_right_hard_divider,
    },
    component_separators = {
      left = wezterm.nerdfonts.pl_left_soft_divider,
      right = wezterm.nerdfonts.pl_right_soft_divider,
    },
    tab_separators = {
      left = wezterm.nerdfonts.pl_left_hard_divider,
      right = wezterm.nerdfonts.pl_right_hard_divider,
    },
  },
  sections = {
    tabline_a = { "mode" },
    tabline_b = { "workspace" },
    tabline_c = { " " },
    tab_active = {
      "index",
      { "parent", padding = 0 },
      "/",
      { "cwd", padding = { left = 0, right = 1 } },
      { "zoomed", padding = 0 },
    },
    tab_inactive = { "index", { "process", padding = { left = 0, right = 1 } } },
    tabline_x = { "ram", "cpu" },
    tabline_y = { "datetime" },
    tabline_z = { "domain" },
  },
  extensions = {},
})

toggle_terminal.apply_to_config(config, {
  key = ";", -- Key for the toggle action
  mods = "SUPER", -- Modifier keys for the toggle action
  direction = "Down", -- Direction to split the pane
  size = { Percent = 30 }, -- Size of the split pane
  change_invoker_id_everytime = false, -- Change invoker pane on every toggle
  zoom = {
    auto_zoom_toggle_terminal = false, -- Automatically zoom toggle terminal pane
    auto_zoom_invoker_pane = true, -- Automatically zoom invoker pane
    remember_zoomed = true, -- Automatically re-zoom the toggle pane if it was zoomed before switching away
  },
})
tabline.apply_to_config(config)

return config
