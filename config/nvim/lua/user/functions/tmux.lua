local M = {}

local function pane_count()
  local out = vim.fn.system("tmux list-panes -F '#{pane_id}'")
  local n = 0
  for _ in out:gmatch("[^\n]+") do
    n = n + 1
  end
  return n
end

local function bottom_pane(format)
  local out = vim.fn.system("tmux list-panes -F '" .. format .. "'")
  local lines = {}
  for line in out:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  return lines[2]
end

-- tmux reads the pane directory from the process, so it comes back resolved,
-- while nvim's own path may still run through a symlink. Both sides get
-- resolved or the comparison reports a difference that is not there.
local function same_dir(a, b)
  if a == nil or b == nil then
    return false
  end

  return (vim.uv.fs_realpath(a) or a) == (vim.uv.fs_realpath(b) or b)
end

function M.open_or_focus()
  if vim.env.TMUX == nil then
    return
  end

  local dir = vim.fn.expand("%:p:h")
  if dir == "" then
    dir = vim.fn.getcwd()
  end

  if pane_count() < 2 then
    vim.fn.system("tmux split-window -v -l 15")
    vim.fn.system("tmux send-keys -t 2 'cd " .. vim.fn.shellescape(dir) .. "' C-m")
  else
    -- Nothing is sent when the pane already sits in the right directory: an
    -- untouched pane keeps whatever was being typed in it. Otherwise C-u leads
    -- the cd, or the cd would glue itself onto that half-typed line. Both are
    -- guarded by the shell check, since C-u means something else to anything
    -- else that could be running there.
    local cmd = bottom_pane("#{pane_current_command}")
    if cmd == "fish" and not same_dir(bottom_pane("#{pane_current_path}"), dir) then
      vim.fn.system("tmux send-keys -t 2 C-u 'cd " .. vim.fn.shellescape(dir) .. "' C-m")
    end
    vim.fn.system("tmux select-pane -t 2")
  end
end

return M
