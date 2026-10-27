return {
  {
    "gbprod/nord.nvim",
    priority = 1000,
    opts = {
      transparent = true,
      terminal_colors = false,
      styles = {
        comments = { italic = true },
      },
    },
    config = function(_, opts)
      require("nord").setup(opts)
      vim.cmd.colorscheme("nord")
    end,
  },
}
