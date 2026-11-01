-- smart-splits v3 ships no multiplexer support of its own; each multiplexer is
-- a separate backend. tmux uses the official one. For wezterm the official
-- backend needs its own GUI plugin in wezterm.lua, which would replace the
-- navigation ring in config/wezterm/nav.lua, so a small inline backend drives
-- the wezterm CLI instead, the way smart-splits v2 did.
local wezterm_directions = { left = "Left", right = "Right", up = "Up", down = "Down" }

local function wezterm_cli(args)
  local result = vim.system(vim.list_extend({ "wezterm", "cli" }, args), { text = true }):wait()
  return result.code == 0, vim.trim(result.stdout or "")
end

-- config/wezterm/nav.lua forwards CTRL/META+hjkl into a pane only while this
-- user var is "true", so nvim has to announce itself.
local function set_is_nvim(value)
  local seq = string.format("\027]1337;SetUserVar=IS_NVIM=%s\007", vim.base64.encode(value))
  if vim.fn.filewritable("/dev/fd/2") == 1 then
    vim.fn.writefile({ seq }, "/dev/fd/2", "b")
  else
    vim.fn.chansend(vim.v.stderr, seq)
  end
end

local wezterm_backend = {
  name = "wezterm-cli",
  protocol_version = "3.0.0",
  -- Inside tmux the tmux backend owns the moves, and pane-nav.sh talks to
  -- wezterm on its behalf.
  detect = function()
    return vim.env.TMUX == nil and (vim.env.WEZTERM_PANE or "") ~= "" and vim.fn.executable("wezterm") == 1
  end,
  move = function(direction)
    local ok, pane = wezterm_cli({ "get-pane-direction", wezterm_directions[direction] })
    if not ok or pane == "" then
      return false
    end
    return (wezterm_cli({ "activate-pane", "--pane-id", pane }))
  end,
  resize = function(direction, opts)
    local amount = tostring((opts and opts.amount) or 1)
    return (wezterm_cli({ "adjust-pane-size", "--amount", amount, wezterm_directions[direction] }))
  end,
  activate = function()
    set_is_nvim("true")
    local group = vim.api.nvim_create_augroup("smart_splits_wezterm_cli", { clear = true })
    vim.api.nvim_create_autocmd({ "VimSuspend", "VimLeavePre" }, {
      group = group,
      callback = function()
        set_is_nvim("false")
      end,
    })
    vim.api.nvim_create_autocmd("VimResume", {
      group = group,
      callback = function()
        set_is_nvim("true")
      end,
    })
  end,
}

return {
  {
    "mrjones2014/smart-splits.nvim",
    dependencies = {
      {
        "smart-splits-nvim/backend-tmux",
        main = "smart-splits-backend-tmux",
        -- Zoomed panes are handled in at_edge below.
        opts = { disable_nav_when_zoomed = false },
      },
    },
    opts = {
      ignored_buftypes = { "nofile", "quickfix", "prompt" },
      ignored_filetypes = { "NeoTree" },
      resize = {
        amount = 1,
        ignored_events = { "BufEnter", "WinEnter" },
      },
      move = {
        -- Reached only when the nvim window *and* the multiplexer pane are both
        -- at the edge. Inside tmux there is still a wezterm layer further out,
        -- so hand the move over to it before falling back to wrapping. Note that
        -- at_edge = "wrap" would let the tmux backend wrap inside tmux and
        -- never let the move escalate.
        at_edge = function(ctx)
          local in_tmux = ctx.backend and ctx.backend.name == "tmux"
          local directions = { left = "Left", right = "Right", up = "Up", down = "Down" }
          local direction = directions[ctx.direction]

          -- A zoomed tmux pane fills its whole window, so tmux reports it as
          -- sitting at every edge at once and the backend gives up before even
          -- trying to move. Ask tmux directly; select-pane unzooms on its way,
          -- which is what makes the keys work without unzooming by hand first.
          if in_tmux and direction then
            local zoomed = vim
              .system({ "tmux", "display-message", "-p", "#{window_zoomed_flag}" }, { text = true })
              :wait()
            if vim.trim(zoomed.stdout or "") == "1" then
              vim.system({ "tmux", "select-pane", "-" .. direction:sub(1, 1) }):wait()
              return
            end
          end

          -- Hand the move to the script the tmux bindings already use, so the
          -- ring is described in one place. Doing it here in Lua is what kept
          -- the ring closing on the tmux panes alone: select-pane wraps inside
          -- tmux before wezterm is ever asked. The script also resolves a live
          -- wezterm socket, which nvim cannot do from its own environment --
          -- the tmux server hands every pane the socket of whichever wezterm
          -- started it, long dead by now.
          local nav = vim.fn.expand("~/.config/tmux/pane-nav.sh")

          if in_tmux and direction and vim.uv.fs_stat(nav) then
            -- Exit code 3 is the script saying nothing out there took the move,
            -- which leaves wrapping among nvim's own windows as the answer.
            if vim.system({ nav, direction }):wait().code ~= 3 then
              return
            end
          end

          ctx.wrap()
        end,
        float = "previous",
        same_row = false,
      },
      swap = {
        move_cursor = false,
      },
      mux = {
        backend = { "smart-splits-backend-tmux", wezterm_backend },
        -- Plain terminals without tmux or wezterm are fine too.
        warn_if_unusable = false,
      },
      log = {
        level = "info",
      },
    },
    config = function(_, opts)
      require("smart-splits").setup(opts)

      local ss = require("smart-splits")

      local function map(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
      end

      map("<A-h>", ss.resize_left, "Resize pane left")
      map("<A-j>", ss.resize_down, "Resize pane down")
      map("<A-k>", ss.resize_up, "Resize pane up")
      map("<A-l>", ss.resize_right, "Resize pane right")
      map("<C-h>", ss.move_cursor_left, "Move Cursor to the Left Pane")
      map("<C-j>", ss.move_cursor_down, "Move Cursor to the Bottom Pane")
      map("<C-k>", ss.move_cursor_up, "Move Cursor to the Upper Pane")
      map("<C-l>", ss.move_cursor_right, "Move Cursor to the Right Pane")
      -- v3 dropped move_cursor_previous; the nvim-only equivalent.
      map("<C-\\>", "<Cmd>wincmd p<CR>", "Move Cursor to Previous Pane")
      map("<leader>Wh", ss.swap_buf_left, "Swap with Left Pane")
      map("<leader>Wj", ss.swap_buf_down, "Swap with Bottom Pane")
      map("<leader>Wk", ss.swap_buf_up, "Swap with Upper Pane")
      map("<leader>Wl", ss.swap_buf_right, "Swap with Right Pane")
    end,
  },
}
