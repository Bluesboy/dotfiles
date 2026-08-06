local function in_tmux()
  return Command("tmux"):arg({ "list-panes" }):output().status.success
end

-- Returns "term", "other", or nil (no second pane)
local function second_pane_state()
  local apps = Command("tmux"):arg({ "list-panes", "-F", "#{pane_current_command}" }):output().stdout
  local lines = {}
  for line in apps:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  if #lines < 2 then return nil end
  local app = lines[2]
  if app == "fish" or app == "tmux" then
    return "term"
  end
  return "other"
end

local function get_work_dir(target)
  return Command("tmux"):arg({ "display-message", "-p", "-F", "#{pane_current_path}", "-t", target }):output().stdout:gsub("[\r\n]+$", "")
end

local function tmux_change_dir(dir)
  -- fs.cwd() hands back a Url userdata while tmux reports a plain string, and
  -- comparing the two is always unequal, so this check never held and the cd
  -- went out on every keypress.
  dir = tostring(dir)

  if get_work_dir(2) ~= dir then
    -- C-u leads the cd: the pane may have been left with a half-typed line the
    -- cd would otherwise glue itself onto. Same send-keys call, so the two
    -- cannot arrive out of order. Nothing is sent when the directory already
    -- matches -- an untouched pane keeps whatever was being typed in it.
    Command("tmux"):arg({ "send-keys", "-t", "2", "C-u", "cd '" .. dir .. "'", "C-m" }):spawn()
  end
end

local function tmux_select_pane(target)
  Command("tmux"):arg({ "select-pane", "-t", target }):output()
end

local function tmux_split_window(size)
  Command("tmux"):arg({ "split-window", "-l", size }):output()
end

return {
  entry = function()
    if not in_tmux() then return end
    local state = second_pane_state()
    if state == "term" then
      tmux_change_dir(fs.cwd())
      tmux_select_pane(2)
    elseif state == "other" then
      tmux_select_pane(2)
    else
      tmux_split_window(15)
    end
  end,
}
