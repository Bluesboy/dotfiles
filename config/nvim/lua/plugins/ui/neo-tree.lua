return {
  "nvim-neo-tree/neo-tree.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
    "s1n7ax/nvim-window-picker",
  },
  cmd = "Neotree",
  keys = {
    { "\\", ":Neotree focus<CR>", desc = "Focus NeoTree", silent = true },
  },
  opts = {
    window = {
      mappings = {
        ["<cr>"] = "open_drop",
        ["l"] = "open",
        ["h"] = "navigate_up",
        ["<bs>"] = "toggle_hidden",
        ["\\"] = "close_window",
        ["<Tab>"] = "next_source",
        ["<S-tab>"] = "prev_source",
        [";"] = "focus_preview",
        ["<space>"] = "select",
      },
      fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
        ["<down>"] = "move_cursor_down",
        ["<C-n>"] = "move_cursor_down",
        ["<up>"] = "move_cursor_up",
        ["<C-p>"] = "move_cursor_up",
        -- ["<esc>"] = "close",
        ["<cr>"] = "close_keep_filter",
        ["<esc>"] = "close_clear_filter",
        ["<C-w>"] = { "<C-S-w>", raw = true },
      },
    },
  },
}
