-- Owned cheatsheet: responsive cards, actual presets, references, and popup cleanup.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind) return kind == "config" and root or stdpath(kind) end
local keymaps = require "keymaps"
vim.fn.stdpath = stdpath
local sheet = require "ui.cheatsheet"
for _, preset in ipairs(keymaps.available()) do
  for _, os_name in ipairs { "linux", "macos" } do
    for _, size in ipairs { 12, 40, 100, 170 } do
      local lines, marks, columns = sheet.render(preset, size, os_name)
      assert(columns == (size >= 140 and 3 or size >= 92 and 2 or 1))
      for _, line in ipairs(lines) do assert(vim.fn.strdisplaywidth(line) <= size, "Cheatsheet overflow") end
      assert(#marks > 20)
      local content = table.concat(lines, "\n")
      assert(content:find("g?", 1, true), "Missing NvimTree help")
    end
  end
end
local linux = table.concat(sheet.render("default", 170, "linux"), "\n")
local mac = table.concat(sheet.render("default", 170, "macos"), "\n")
assert(linux:find("Space ch", 1, true) and linux:find("Ctrl-v", 1, true))
assert(not linux:find("Cmd-s", 1, true) and mac:find("Cmd-s", 1, true))
keymaps.setup()
assert(vim.fn.maparg(" ch", "n"):find("Cheatsheet", 1, true))
local original = vim.api.nvim_get_current_win()
vim.cmd "NvCheatsheet"
local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
assert(vim.bo[buf].filetype == "cheatsheet" and not vim.bo[buf].modifiable)
assert(vim.api.nvim_win_get_config(win).relative == "editor")
assert(vim.fn.search("NvimTree", "w") > 0, "Native search doesn't find a section")
vim.api.nvim_exec_autocmds("VimResized", {})
vim.fn.maparg("q", "n", false, true).callback()
assert(not vim.api.nvim_buf_is_valid(buf) and not vim.api.nvim_win_is_valid(win))
assert(vim.api.nvim_get_current_win() == original)
assert(vim.fn.exists "#OwnedCheatsheetWindow" == 0, "Popup autocmds leaked")
vim.cmd "Cheatsheet vscode"
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find("vscode", 1, true))
sheet.toggle()
assert(vim.api.nvim_get_current_win() == original)
assert(not pcall(sheet.open, "missing-preset"))
assert(vim.api.nvim_get_current_win() == original, "Invalid preset created a popup")
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Cheatsheet: 1/2/3-column layouts, all presets/OSes, tree references, commands, search, resize, and cleanup passed"
