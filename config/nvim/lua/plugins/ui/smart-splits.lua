return {
  {
    "mrjones2014/smart-splits.nvim",
    opts = {
      ignored_buftypes = { "nofile", "quickfix", "prompt" },
      ignored_filetypes = { "NeoTree" },
      default_amount = 1,
      -- Reached only when the nvim window *and* the multiplexer pane are both
      -- at the edge. Inside tmux there is still a wezterm layer further out,
      -- so hand the move over to it before falling back to wrapping. Note that
      -- at_edge = "wrap" would skip the multiplexer edge check entirely and
      -- never let the move escalate.
      at_edge = function(ctx)
        -- A zoomed tmux pane fills its whole window, so tmux reports it as
        -- sitting at every edge at once and smart-splits gives up before even
        -- trying to move. Ask tmux directly; select-pane unzooms on its way,
        -- which is what makes the keys work without unzooming by hand first.
        if ctx.mux and ctx.mux.type == "tmux" and ctx.mux.current_pane_is_zoomed() then
          ctx.mux.next_pane(ctx.direction)
          return
        end

        -- Hand the move to the script the tmux bindings already use, so the
        -- ring is described in one place. Doing it here in Lua is what kept
        -- the ring closing on the tmux panes alone: ctx.mux.next_pane is
        -- select-pane, which wraps inside tmux before wezterm is ever asked.
        -- The script also resolves a live wezterm socket, which nvim cannot
        -- do from its own environment -- the tmux server hands every pane the
        -- socket of whichever wezterm started it, long dead by now.
        local directions = { left = "Left", right = "Right", up = "Up", down = "Down" }
        local direction = directions[ctx.direction]
        local nav = vim.fn.expand("~/.config/tmux/pane-nav.sh")

        if ctx.mux and ctx.mux.type == "tmux" and direction and vim.uv.fs_stat(nav) then
          -- Exit code 3 is the script saying nothing out there took the move,
          -- which leaves wrapping among nvim's own windows as the answer.
          if vim.system({ nav, direction }):wait().code ~= 3 then
            return
          end
        end

        ctx.wrap()
      end,
      float_win_behavior = "previous",
      move_cursor_same_row = false,
      cursor_follows_swapped_bufs = false,
      ignored_events = { "BufEnter", "WinEnter" },
      -- Left unset on purpose: setting it disables auto-detection.
      -- smart-splits picks the back-end from $TERM_PROGRAM, so nvim inside
      -- tmux drives tmux, and nvim straight in wezterm drives wezterm.
      disable_multiplexer_nav_when_zoomed = false,
      kitty_password = nil,
      zellij_move_focus_or_tab = false,
      log_level = "info",
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
      map("<C-\\>", ss.move_cursor_previous, "Move Cursor to Preview Pane")
      map("<leader>Wh", ss.swap_buf_left, "Swap with Left Pane")
      map("<leader>Wj", ss.swap_buf_down, "Swap with Bottom Pane")
      map("<leader>Wk", ss.swap_buf_up, "Swap with Upper Pane")
      map("<leader>Wl", ss.swap_buf_right, "Swap with Right Pane")
    end,
  },
}
