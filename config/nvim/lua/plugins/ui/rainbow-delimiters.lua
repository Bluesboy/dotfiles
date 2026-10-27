local highlight = {
  "RainbowRed",
  "RainbowYellow",
  "RainbowBlue",
  "RainbowOrange",
  "RainbowGreen",
  "RainbowViolet",
  "RainbowCyan",
}

return {
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local hooks = require("ibl.hooks")

      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#BF616A" })
        vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#EBCB8B" })
        vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#81A1C1" })
        vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D08770" })
        vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#A3BE8C" })
        vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#B48EAD" })
        vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#88C0D0" })
      end)

      vim.opt.list = true
      vim.opt.listchars:append("eol:↴")

      require("ibl").setup({ indent = { highlight = highlight } })
    end,
    main = "ibl",
    opts = {},
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "lukas-reineke/indent-blankline.nvim",
    },
    config = function()
      require("rainbow-delimiters.setup").setup({})
      vim.g.rainbow_delimiters = { highlight = highlight }
    end,
  },
}
