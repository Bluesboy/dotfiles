local options = {
  backup = false, -- creates a backup file
  clipboard = "unnamedplus", -- allows neovim to access the system clipboard
  backspace = "indent,start", -- do not delete EOL
  cmdheight = 2, -- more space in the neovim command line for displaying messages
  completeopt = { "menuone", "noselect" }, -- mostly just for cmp
  conceallevel = 0, -- so that `` is visible in markdown files
  fileencoding = "utf-8", -- the encoding written to a file
  hlsearch = true, -- highlight all matches on previous search pattern
  inccommand = "split", -- preview substitutions live, as you type!
  ignorecase = true, -- ignore case in search patterns
  smartcase = true, -- smart case
  mouse = "a", -- allow the mouse to be used in neovim
  pumheight = 10, -- pop up menu height
  -- showmode = false, -- we don't need to see things like -- INSERT -- anymore
  -- showtabline = 2, -- always show tabs
  expandtab = true, -- convert tabs to spaces
  shiftwidth = 2, -- the number of spaces inserted for each indentation
  tabstop = 2, -- insert 2 spaces for a tab
  softtabstop = 2, -- insert 2 spaces for a softtab
  autoindent = true, -- indent lines below like current
  smartindent = true, -- make indenting smarter again
  splitbelow = true, -- force all horizontal splits to go below current window
  splitright = true, -- force all vertical splits to go to the right of current window
  swapfile = false, -- creates a swapfile
  termguicolors = true, -- set term gui colors (most terminals support this)
  timeoutlen = 500, -- time to wait for a mapped sequence to complete (in milliseconds)
  undofile = true, -- enable persistent undo
  updatetime = 250, -- faster completion (4000ms default)
  writebackup = false, -- if a file is being edited by another program (or was written to file while editing with another program), it is not allowed to be edited
  cursorline = true, -- highlight the current line
  number = true, -- set numbered lines
  relativenumber = true, -- set relative numbered lines
  numberwidth = 2, -- set number column width to 2 {default 4}
  signcolumn = "yes", -- always show the sign column, otherwise it would shift the text each time
  wrap = false, -- display lines as one long line
  scrolloff = 8, -- is one of my fav
  sidescrolloff = 8,
  guifont = "monospace:h17", -- the font used in graphical neovim applications
  whichwrap = "<,>,[,],h,l", --
  laststatus = 3, -- enable global statusline
}
-- Disable netrw
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.shortmess:append("c")
vim.lsp.log.set_level("off")

for key, value in pairs(options) do
  vim.opt[key] = value
end

-- Langmap: normal mode commands typed in the Russian layout.
-- Must be set before langmapper.setup() runs (it only handles mappings).
local function escape_langmap(str)
  -- These characters are meaningful inside 'langmap' itself
  return vim.fn.escape(str, [[;,."|\]])
end

local en = [[`qwertyuiop[]asdfghjkl;'zxcvbnm,.]]
local ru = [[ёйцукенгшщзхъфывапролджэячсмитьбю]]
local en_shift = [[~QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>]]
local ru_shift = [[ЁЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ]]

vim.opt.langmap = vim.fn.join({
  -- typed characters first, what they mean second
  escape_langmap(ru_shift) .. ";" .. escape_langmap(en_shift),
  escape_langmap(ru) .. ";" .. escape_langmap(en),
}, ",")

-- Detect Ansible YAML files as yaml.ansible so ansiblels takes over yamlls
vim.filetype.add({
  pattern = {
    [".*/tasks/.*%.ya?ml"] = "yaml.ansible",
    [".*/handlers/.*%.ya?ml"] = "yaml.ansible",
    [".*/roles/.*/.*%.ya?ml"] = "yaml.ansible",
    [".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
    [".*ansible.*%.ya?ml"] = "yaml.ansible",
    -- Files with #!/usr/bin/env ansible-playbook shebang
    [".*%.ya?ml"] = {
      function(_, bufnr)
        local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
        if first_line:match("^#!/usr/bin/env ansible%-playbook") then
          return "yaml.ansible"
        end
      end,
      priority = math.huge,
    },
  },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "lua",
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "yaml*",
  callback = function()
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
    vim.bo.smartindent = true
    vim.bo.autoindent = true
  end,
})

-- Used by telescope, which-key and other plugins to enable Nerd Font icons
vim.g.have_nerd_font = true
