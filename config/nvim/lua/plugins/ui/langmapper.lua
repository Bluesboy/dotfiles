-- Ask niri which xkb layout is active right now.
-- Langmapper needs this only for keys that produce ASCII in both layouts
-- (`.`, `,`, `/`), where `langmap` alone cannot tell them apart.
local function niri_layout_id()
  if vim.fn.executable("niri") == 0 then
    return
  end

  local res = vim.system({ "niri", "msg", "--json", "keyboard-layouts" }):wait()
  if res.code ~= 0 then
    return
  end

  local ok, layouts = pcall(vim.json.decode, res.stdout)
  if not ok or type(layouts) ~= "table" then
    return
  end

  return layouts.names[layouts.current_idx + 1]
end

return {
  {
    "Wansmer/langmapper.nvim",
    lazy = false,
    -- Must run before any other plugin registers a mapping: `hack_keymap`
    -- wraps `nvim_(buf_)set_keymap`, so only later calls get translated.
    priority = 1001,
    config = function()
      local langmapper = require("langmapper")

      -- Insert mode stays untranslated by default, so `jk` keeps working.
      langmapper.setup({
        layouts = {
          ru = {
            -- Must match a name from `niri msg keyboard-layouts`
            id = "Russian",
            -- Same table as upstream, except the first character: upstream
            -- ships a Latin "E" with diaeresis there, so <S-`> never translated
            layout = [[ЁЙЦУКЕНГШЩЗХЪ/ФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,ёйцукенгшщзхъфывапролджэячсмитьбю.]],
          },
        },
        os = {
          Linux = {
            get_current_layout_id = niri_layout_id,
          },
        },
      })

      -- Hide the generated Cyrillic mappings from `nvim_get_keymap`, otherwise
      -- which-key and blink list every mapping twice.
      langmapper.hack_get_keymap()
    end,
  },
}
