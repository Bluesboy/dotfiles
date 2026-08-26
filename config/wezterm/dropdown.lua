-- Config for the dropdown terminal spawned by niri/dropdown.sh.
--
-- It reuses the main config verbatim. The window is told apart by app_id, which
-- the script sets with --class, so nothing here has to carry that; the pinned
-- title is only there to keep the window readable in `niri msg windows` and in
-- anything else that lists windows by name.

local wezterm = require("wezterm")

local config = dofile(wezterm.config_dir .. "/wezterm.lua")

wezterm.on("format-window-title", function()
  return "dropdown"
end)

return config
