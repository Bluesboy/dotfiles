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
        local wezterm_directions = { left = "Left", right = "Right", up = "Up", down = "Down" }
        local direction = wezterm_directions[ctx.direction]

        -- pcall guards the case of a tmux session detached from wezterm, where
        -- WEZTERM_PANE is stale and the wezterm CLI is unreachable.
        if ctx.mux and ctx.mux.type == "tmux" and direction and vim.env.WEZTERM_PANE then
          local ok, moved = pcall(function()
            local probe = vim.system({ "wezterm", "cli", "get-pane-direction", direction }):wait()

            if probe.code ~= 0 or vim.trim(probe.stdout or "") == "" then
              return false
            end

            vim.system({ "wezterm", "cli", "activate-pane-direction", direction }):wait()
            return true
          end)

          if ok and moved then
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
