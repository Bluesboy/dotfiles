-- Config for the dropdown terminal spawned by niri/dropdown.sh.
--
-- wezterm 20240203 maps no window at all when --class is combined with its
-- native Wayland backend, so the dropdown cannot be told apart by app_id: it
-- reports the same org.wezfurlong.wezterm as every other window. It therefore
-- reuses the main config verbatim and only pins the window title, which
-- niri/config.kdl matches on instead.

local wezterm = require("wezterm")

local config = dofile(wezterm.config_dir .. "/wezterm.lua")

wezterm.on("format-window-title", function()
  return "dropdown"
end)

return config
