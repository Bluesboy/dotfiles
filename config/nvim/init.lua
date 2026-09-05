require "user.functions"
require "user.options"
require "user.keymaps"
require "lazy-nvim"

-- Mappings from `user.keymaps` and vim script are registered before langmapper
-- wraps `nvim_set_keymap`, so translate whatever is already there.
require("langmapper").automapping({ global = true, buffer = false })
