local wezterm = require("wezterm")

local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
local toggle_terminal = wezterm.plugin.require("https://github.com/zsh-sage/toggle_terminal.wez")

local M = {}

function M.apply_to_config(config)
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

  -- Must run after toggle_terminal so the tab bar reflects its panes.
  tabline.apply_to_config(config)
end

return M
