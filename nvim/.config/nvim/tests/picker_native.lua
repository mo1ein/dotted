-- Real native picker/dialog integration, including failed-save preview rollback.
assert(vim.env.NVIM_TEST_ISOLATED == "1", "Native picker tests require isolated XDG dirs")
local loader = require "config.theme_loader"
local selection = require "themes.selection"
local executable = vim.fn.executable
vim.fn.executable = function() return 0 end
vim.cmd "ThemeReset"
local original = loader.current()
local function press(key) vim.fn.maparg(key, "n", false, true).callback() end
local function choose(name)
  local popup = loader.pick()
  assert(vim.api.nvim_win_get_height(popup.win) <= 10)
  local items = vim.api.nvim_buf_get_lines(popup.buf, 0, -1, false)
  local row
  for i, item in ipairs(items) do if item == name then row = i; break end end
  assert(row, "Missing theme: " .. name)
  vim.api.nvim_win_set_cursor(popup.win, { row, 0 })
  press "<CR>"
  assert(not vim.api.nvim_win_is_valid(popup.win))
  assert(vim.bo.filetype == "theme-confirm", "Native picker didn't focus the confirmation")
  vim.wait(50) -- process the picker's queued close callback
  assert(loader.current() == name, "Picker close canceled a pending confirmation")
end
choose "jb"
assert(selection.read() == nil, "Enter saved before confirmation")
press "<Esc>"
assert(loader.current() == original and selection.read() == nil)
choose "jb"
press "y"
assert(loader.current() == "jb" and selection.read() == "jb")

-- A real read-only config write must preserve the saved choice and original UI.
assert(vim.uv.fs_chmod(selection.path(), 292))
local notify, reported = vim.notify, false
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR and message:find("not saved", 1, true) then reported = true
  else notify(message, level) end
end
choose "dotted-onedark"
press "y"
assert(reported and loader.current() == "jb" and selection.read() == "jb", "Failed save didn't roll back")
assert(loader.startup() == "jb", "Failed save changed the startup preference")
assert(vim.uv.fs_chmod(selection.path(), 420))
vim.notify, vim.fn.executable = notify, executable
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Native picker: half-height, real confirmation, Escape, saved choice, and read-only rollback passed"
vim.cmd "qa!"
