-- Persistence tests use their own temporary config/state roots, never user files.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local stdpath = vim.fn.stdpath
local temporary = vim.fn.tempname()
vim.fn.stdpath = function(kind)
  if kind == "config" or kind == "state" then return temporary .. "/" .. kind end
  return stdpath(kind)
end
local selection = require "themes.selection"
vim.fn.mkdir(vim.fn.fnamemodify(selection.legacy_path(), ":h"), "p")
vim.fn.writefile({ "jb" }, selection.legacy_path())
assert(selection.save("vscode-dark-2026"))
assert(selection.read() == "vscode-dark-2026")
assert(vim.fn.filereadable(selection.legacy_path()) == 0)
local raw = table.concat(vim.fn.readfile(selection.path()), "\n")
assert(raw:find('return "vscode-dark-2026"', 1, true))
assert(not selection.save("bad\nname"))
assert(selection.read() == "vscode-dark-2026")
assert(vim.uv.fs_chmod(selection.path(), 292)) -- 0444: don't bypass read-only config
assert(not selection.save("jb"))
assert(selection.read() == "vscode-dark-2026")
assert(vim.uv.fs_chmod(selection.path(), 420))
assert(selection.reset() and selection.read() == nil)

local target = temporary .. "/choice.lua"
vim.fn.writefile({ 'return "jb"' }, target)
assert(vim.uv.fs_symlink(target, selection.path()))
assert(selection.save("dotted-onedark"))
assert(vim.uv.fs_lstat(selection.path()).type == "link", "Saving replaced a user's symlink")
assert(selection.read() == "dotted-onedark")
assert(selection.reset())
assert(vim.fn.filereadable(target) == 1, "Reset deleted the symlink target")
vim.fn.stdpath = stdpath
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Selection: config-backed save/read/reset, legacy migration, read-only failure, and symlink preservation passed"
