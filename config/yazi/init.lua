-- Replaced dedukun/bookmarks, which was unmaintained and still called the
-- ya.mgr_emit API yazi removed. Owns m / ' / bd / bf.
--
-- No config bookmarks on purpose: those cannot be deleted from inside yazi.
-- Everything lives in the state file below, added and removed from inside yazi.
require("whoosh"):setup({
  jump_notify = false,
  -- The default sits inside the plugin directory, which ya pkg owns and wipes
  -- on upgrade. Runtime bookmarks belong in the state directory instead.
  bookmarks_path = os.getenv("HOME") .. "/.local/state/yazi/whoosh-bookmarks",
})

require("starship"):setup({
  hide_flags = false,
  flags_after_prompt = true,
})

-- toggle_mode_key is left at its ctrl-t default. Note that wezterm binds plain
-- CTRL+T to SpawnTab, so if the key never reaches fzf that is the reason.
require("yafg"):setup({
  editor = "nvim",
  file_arg_format = "+{row} {file}",
})

require("git"):setup()

require("session"):setup({
  sync_yanked = true,
})

require("projects"):setup({
  event = {
    save = {
      enable = true,
      name = "project-saved",
    },
    load = {
      enable = true,
      name = "project-loaded",
    },
    delete = {
      enable = true,
      name = "project-deleted",
    },
    delete_all = {
      enable = true,
      name = "project-deleted-all",
    },
    merge = {
      enable = true,
      name = "project-merged",
    },
  },
  save = {
    method = "yazi",
    yazi_load_event = "@projects-load",
    lua_save_path = "",
  },
  last = {
    update_after_save = true,
    update_after_load = true,
    update_before_quit = false,
    load_after_start = false,
  },
  merge = {
    event = "projects-merge",
    quit_after_merge = false,
  },
  notify = {
    enable = true,
    title = "Projects",
    timeout = 3,
    level = "info",
  },
})

require("eza-preview"):setup({
  -- Set the tree preview to be default (default: true)
  default_tree = true,

  -- Directory depth level for tree preview (default: 3)
  level = 3,

  -- Show file icons
  icons = true,

  -- Follow symlinks when previewing directories (default: true)
  follow_symlinks = true,

  -- Show target file info instead of symlink info (default: false)
  dereference = false,

  -- Show hidden files (default: true)
  all = true,

  -- Ignore files matching patterns (default: {})
  -- ignore_glob = "*.log"
  -- ignore_glob = { "*.tmp", "node_modules", ".git", ".DS_Store" }
  -- SEE: https://www.linuxjournal.com/content/pattern-matching-bash to learn about glob patterns
  ignore_glob = {},

  -- Ignore files mentioned in '.gitignore'  (default: true)
  git_ignore = false,

  -- Show git status (default: false)
  git_status = false,
})

-- Or use default settings
require("eza-preview"):setup({})
