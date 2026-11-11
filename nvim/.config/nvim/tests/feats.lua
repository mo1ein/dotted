-- Regression coverage for feats.md: real split geometry, explorer and toolbar.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
vim.o.columns, vim.o.lines = 180, 48
local dir = vim.fn.tempname()
vim.fn.mkdir(dir .. "/needle-dir", "p")
vim.fn.mkdir(dir .. "/unrelated", "p")
vim.fn.writefile({ "print('feature run')" }, dir .. "/needle.py")
vim.cmd.edit(vim.fn.fnameescape(dir .. "/needle.py"))
local first = vim.api.nvim_get_current_win()
vim.cmd.vsplit()
local second = vim.api.nvim_get_current_win()
vim.cmd.split()
local third = vim.api.nvim_get_current_win()
require("lazy").load { plugins = { "nvim-tree.lua" } }
local api = require "nvim-tree.api"
api.tree.open { path = dir }
local tree = api.tree.winid()
assert(vim.fn.maparg("<C-f>", "n", false, true).buffer == 1, "Tree search isn't local")
assert(vim.wo[tree].winbar:find("explorer", 1, true))
local tools = require "ui.tools"
tools.show("Terminal")
local drawer = tools.current().win
local x = vim.api.nvim_win_get_position(drawer)[2]
local w = vim.api.nvim_win_get_width(drawer)
assert(x > 0 and x + w == vim.o.columns, "Drawer doesn't span both editor columns")
for _, win in ipairs { first, second, third } do
  local pos = vim.api.nvim_win_get_position(win)
  assert(pos[1] < vim.api.nvim_win_get_position(drawer)[1] and pos[2] >= x)
end
local one = tools.current().buf
tools.new_terminal()
local two = tools.current().buf
assert(one ~= two and #tools.current().terminals == 2)
tools.cycle_terminal(-1)
assert(tools.current().buf == one)
tools.cycle_terminal(1)
assert(tools.current().buf == two)
local header = tools.header()
local strip = tools.current().strip
local sessions = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(strip), 0, 1, false)[1]
assert(sessions:find("zsh 2", 1, true) and not header:find("zsh", 1, true))
local rendered = vim.api.nvim_eval_statusline(header, { winid = drawer, use_winbar = true, maxwidth = w, highlights = true })
local spans = rendered.highlights
for i, span in ipairs(spans) do
  if span.group == "DottedToolPadInactive" then
    local stop = spans[i + 1] and spans[i + 1].start or #rendered.str
    assert(not rendered.str:sub(span.start + 1, stop):match("%S"), "Tab background bleeds into a label")
  end
end
tools.hide()
vim.api.nvim_set_current_win(first)
local replace = require("ui.replace").buffer { search = "print", start_in_insert = false }
local marks = vim.api.nvim_buf_get_extmarks(replace.target, replace.namespace, 0, -1, { details = true })
assert(#marks > 0 and marks[1][4].priority == 250, "Replace highlight hidden by syntax")
require("ui.replace").close()
assert(vim.o.cursorlineopt == "both" and vim.o.guicursor:find("i%-ci%-ve:ver25"))
assert(vim.o.guicursor:find("blinkon250", 1, true))
for _, scheme in ipairs { "vscode-light-modern", "dotted-onedark" } do
  assert(require("config.theme_loader").apply(scheme, false))
  local hl = vim.api.nvim_get_hl(0, { name = "Search", link = false })
  assert(require("ui.color").contrast(hl.fg, hl.bg) >= 4.5)
  assert(require("ui.bufferline").render():find("DottedThemeClick", 1, true))
end
vim.api.nvim_set_current_win(tree)
local explorer = require "ui.explorer"
-- Creation and movement use public controls, with deterministic prompt answers.
local prompt = explorer.folder()
vim.api.nvim_buf_set_lines(prompt.buf, 0, -1, false, { dir .. "/created-folder" })
vim.fn.maparg("<CR>", "n", false, true).callback()
assert(vim.fn.isdirectory(dir .. "/created-folder") == 1)
explorer.action(3) -- Reproduce the reported collapse button, using the real API.
explorer.action(5)
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.fn.maparg("<CR>", "n", false, true).callback()
assert(explorer.sort == "extension")
explorer.move()
vim.api.nvim_win_set_cursor(0, { 2, 0 })
vim.fn.maparg("<CR>", "n", false, true).callback()
assert(vim.api.nvim_win_get_position(tree)[2] > 0)
-- Run from explorer focus must resolve the editor rather than the tree buffer.
local runner = package.loaded["util.run_file"]
local called
package.loaded["util.run_file"] = function() called = vim.bo.filetype end
require("util.run").file()
assert(called == "python")
package.loaded["util.run_file"] = runner
for _, preset in ipairs(require("keymaps").available()) do
  for _, os in ipairs { "linux", "macos" } do
    for _, entry in ipairs(require("keymaps").resolve(os, preset).bindings) do
      if entry.action == "find.replace_buffer" then assert(vim.tbl_contains(entry.keys, "<C-r>")) end
    end
  end
end
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Feature regressions: multi-column drawer, terminal tabs, explorer controls, source run, replace priority, cursor and theme colors passed"
