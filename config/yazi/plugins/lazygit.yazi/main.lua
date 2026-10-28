return {
  entry = function()
    local output = Command("git"):arg({ "rev-parse", "--git-dir" }):cwd(tostring(fs.cwd())):output()
    if not output or not output.status.success then
      ya.notify({
        title = "lazygit",
        content = "Not a git repository",
        level = "warn",
        timeout = 5,
      })
      return
    end

    -- Yazi hands block shells a raw tty. lazygit saves that mode at startup
    -- and restores it for its subprocesses, so "Press enter to return" never
    -- sees Enter. stty sane gives lazygit a cooked tty to save instead.
    ya.emit("shell", { "stty sane; lazygit", block = true })
  end,
}
