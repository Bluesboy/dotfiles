local wezterm = require("wezterm")

-- Pane navigation shared with tmux and nvim.
--
-- CTRL+hjkl moves, META+hjkl resizes, and the same keys mean the same thing at
-- every nesting level. wezterm is the outermost layer, so it only acts once the
-- inner layers report they are at their edge:
--
--   nvim window -> tmux pane -> wezterm pane
--
-- nvim escalates through its smart-splits `at_edge` callback and tmux through
-- the `#{pane_at_*}` bindings in tmux.conf, both by shelling out to
-- `wezterm cli activate-pane-direction`. So whenever a pane runs nvim or tmux,
-- wezterm must forward the key instead of consuming it.

local M = {}

local direction_keys = { "h", "j", "k", "l" }

local directions = {
  h = "Left",
  j = "Down",
  k = "Up",
  l = "Right",
}

local function is_nvim(pane)
  return pane:get_user_vars().IS_NVIM == "true"
end

local function is_tmux(pane)
  local process = pane:get_foreground_process_name()
  return process ~= nil and process:match("[/\\]tmux$") ~= nil
end

local function nav(resize_or_move, key)
  local mods = resize_or_move == "resize" and "META" or "CTRL"
  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(win, pane)
      -- A lone pane has nowhere to move to, so forwarding keeps keys such as
      -- CTRL+l usable in a plain shell.
      local single_pane = #win:active_tab():panes() == 1

      if single_pane or is_nvim(pane) or is_tmux(pane) then
        win:perform_action({ SendKey = { key = key, mods = mods } }, pane)
      elseif resize_or_move == "resize" then
        win:perform_action({ AdjustPaneSize = { directions[key], 1 } }, pane)
      else
        win:perform_action({ ActivatePaneDirection = directions[key] }, pane)
      end
    end),
  }
end

function M.apply_to_config(config)
  config.keys = config.keys or {}

  for _, key in ipairs(direction_keys) do
    table.insert(config.keys, nav("move", key))
    table.insert(config.keys, nav("resize", key))
  end

  return config
end

return M
