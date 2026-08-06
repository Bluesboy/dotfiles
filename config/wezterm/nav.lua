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
-- the `#{pane_at_*}` bindings in tmux.conf; both end up in
-- `config/tmux/pane-nav.sh`, which drives the wezterm CLI on their behalf. So
-- whenever a pane runs nvim or tmux, wezterm must forward the key instead of
-- consuming it -- the inner layer decides whether the move reaches this one.

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

-- Which coordinate each key travels along, and in which direction. `axis` is the
-- field of PaneInformation to compare, `sign` is +1 when the key moves towards
-- growing coordinates.
local axes = {
  h = { axis = "left", sign = -1 },
  l = { axis = "left", sign = 1 },
  k = { axis = "top", sign = -1 },
  j = { axis = "top", sign = 1 },
}

-- The pane the move should land on once it runs out of panes ahead of it: the
-- one furthest back along the same axis. Going down from the bottom pane wraps
-- to the topmost one, matching how tmux's select-pane already behaves.
local function wrap_target(panes, key)
  local axis, sign = axes[key].axis, axes[key].sign
  local target

  for _, p in ipairs(panes) do
    if target == nil or (p[axis] - target[axis]) * sign < 0 then
      target = p
    end
  end

  return target
end

local function pane_ahead(panes, current, key)
  local axis, sign = axes[key].axis, axes[key].sign

  for _, p in ipairs(panes) do
    if (p[axis] - current[axis]) * sign > 0 then
      return true
    end
  end

  return false
end

local function nav(resize_or_move, key)
  local mods = resize_or_move == "resize" and "META" or "CTRL"
  return {
    key = key,
    mods = mods,
    action = wezterm.action_callback(function(win, pane)
      local panes = win:active_tab():panes_with_info()

      -- A lone pane has nowhere to move to, so forwarding keeps keys such as
      -- CTRL+l usable in a plain shell.
      if #panes == 1 or is_nvim(pane) or is_tmux(pane) then
        win:perform_action({ SendKey = { key = key, mods = mods } }, pane)
        return
      end

      if resize_or_move == "resize" then
        win:perform_action({ AdjustPaneSize = { directions[key], 1 } }, pane)
        return
      end

      local current
      for _, p in ipairs(panes) do
        if p.is_active then
          current = p
        end
      end

      if current ~= nil and not pane_ahead(panes, current, key) then
        wrap_target(panes, key).pane:activate()
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
