local wezterm = require("wezterm")

local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
local toggle_terminal = wezterm.plugin.require("https://github.com/zsh-sage/toggle_terminal.wez")

local M = {}

local toggle_terminal_opts = {
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
}

-- Resolved once the plugin has run, since that is what puts its own directory
-- on package.path. Holds the same module instance the plugin's key binding
-- drives, options already merged.
local terminal = nil

-- The toggle pane is created once per tab and reused, so it keeps the working
-- directory it was born with. A freshly split pane inherits the invoker's
-- directory on its own, so only the reused one is ever actually behind.
local shells = { bash = true, dash = true, fish = true, ksh = true, sh = true, zsh = true }

local function pane_cwd(pane)
  local cwd = pane:get_current_working_dir()

  -- nil until the shell emits OSC 7; wezterm never guesses the directory.
  if cwd == nil then
    return nil
  end

  return { path = cwd.file_path, host = cwd.host }
end

local function is_shell(pane)
  local process = pane:get_foreground_process_name()

  return process ~= nil and shells[process:match("[^/\\]+$") or ""] == true
end

-- The plugin's own state file. Reading it beats keeping a second record of
-- which pane is the terminal: this one is what the plugin itself reloads from,
-- so the two cannot drift apart.
local function terminal_pane_id(tab_id)
  local path = string.format("%s/tmp/wezterm_toggle_pane_tab_%s.json", wezterm.config_dir, tab_id)
  local file = io.open(path, "r")

  if file == nil then
    return nil
  end

  local content = file:read("*a")
  file:close()

  local ok, data = pcall(wezterm.json_parse, content)

  if not ok or type(data) ~= "table" or type(data.state_table) ~= "table" then
    return nil
  end

  return data.state_table.pane_id
end

-- Toggle, then bring the terminal to the directory it was called from.
function M.toggle_terminal_with_cwd(window, pane)
  -- Toggling away from the terminal lands on the invoker, which must keep its
  -- own directory, so there is nothing to carry in that direction.
  local leaving = terminal_pane_id(pane:tab():tab_id()) == pane:pane_id()
  local from = (not leaving) and pane_cwd(pane) or nil

  terminal.toggle_terminal(window, pane)

  if from == nil or from.path == nil then
    return
  end

  local target = window:active_pane()

  if target == nil or target:pane_id() == pane:pane_id() or not is_shell(target) then
    return
  end

  local to = pane_cwd(target)

  -- Already there, or sitting on another host where the path means nothing.
  if to ~= nil and (to.host ~= from.host or to.path == from.path) then
    return
  end

  -- CTRL+U first, or the cd glues itself onto whatever half-typed line the
  -- pane was left with.
  target:send_text("\025cd '" .. from.path:gsub("'", [['\'']]) .. "'\n")
end

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

  toggle_terminal.apply_to_config(config, toggle_terminal_opts)

  -- apply_to_config is still the way in: it merges the options and puts the
  -- plugin on package.path. Only its key binding is swapped afterwards, for
  -- the wrapper that carries the working directory along.
  terminal = require("lua.toggle_terminal")

  for _, entry in ipairs(config.keys) do
    if entry.key == toggle_terminal_opts.key and entry.mods == toggle_terminal_opts.mods then
      entry.action = wezterm.action_callback(M.toggle_terminal_with_cwd)
      break
    end
  end

  -- Must run after toggle_terminal so the tab bar reflects its panes.
  tabline.apply_to_config(config)
end

return M
