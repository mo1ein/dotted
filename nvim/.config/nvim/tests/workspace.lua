-- Numbered buffers, release-driven MRU cycling, and async path dropdowns.
assert(vim.env.NVIM_TEST_ISOLATED == "1", "Use isolated XDG directories")
local registry = require "ui.buffers"
for _, buf in ipairs(registry.list()) do vim.bo[buf].buflisted = false end
local directory = vim.fn.tempname() .. " workspace 100%"
vim.fn.mkdir(directory .. "/.config/nested", "p")
vim.fn.mkdir(directory .. "/.git", "p")
directory = assert(vim.uv.fs_realpath(directory))
local buffers = {}
for index = 1, 12 do
  local file = directory .. "/file" .. index .. ".txt"
  vim.fn.writefile({ "file " .. index }, file)
  local buf = vim.fn.bufadd(file)
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = true
  buffers[index] = buf
end
for _, index in ipairs { 1, 6, 2, 9 } do vim.api.nvim_set_current_buf(buffers[index]) end
assert(vim.deep_equal(vim.list_slice(registry.recent(), 1, 4), { buffers[9], buffers[2], buffers[6], buffers[1] }), "Fast MRU order is wrong")
local stable = registry.list()
vim.api.nvim_buf_set_lines(buffers[9], 0, -1, false, { "unsaved text" })
local tabline = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = 300 }).str
assert(tabline:find("file9.txt ● [9]", 1, true), "Full-size suffix number is missing: " .. tabline)
assert(vim.api.nvim_get_hl(0, { name = "DottedBufNumber", link = false }).bold, "Numbers aren't bold")
vim.cmd "BufferGo 12"
assert(vim.api.nvim_get_current_buf() == buffers[12])
vim.api.nvim_feedkeys(" 3", "xt", false)
assert(vim.api.nvim_get_current_buf() == buffers[3], "Space+number did not jump")
assert(vim.deep_equal(stable, registry.list()), "MRU switching reordered tab numbers")
assert(vim.bo[buffers[9]].modified, "Number jump lost unsaved work")
local modifiers = require "ui.modifiers"
modifiers.is_down = function() return true end -- synthetic input holds Option
local recent = registry.recent()
local switcher = require "ui.switcher"
switcher.cycle("next")
switcher.cycle("next")
assert(vim.api.nvim_get_current_buf() == recent[3], "Switcher didn't preview the selected file")
assert(vim.wait(1500, function() return vim.api.nvim_get_current_buf() == recent[3] end, 10), "MRU cycling didn't advance beyond the previous file")
switcher.cycle("next")
switcher.cycle("prev")
assert(switcher.current(), "Switcher closed while Option was held")
modifiers.is_down = function() return false end
assert(vim.wait(1000, function() return not switcher.current() end, 5), "Switcher didn't close on release")
modifiers.is_down = function() return true end
-- Leaving the source window or deleting a candidate during the session must not
-- write a file into a utility pane or raise a stale-buffer scheduled callback.
vim.api.nvim_set_current_buf(buffers[1])
vim.api.nvim_set_current_buf(buffers[6])
local next_buffer = registry.recent()[2]
switcher.cycle("next")
local utility = vim.api.nvim_create_buf(false, true)
vim.cmd "botright split"
local utility_win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(utility_win, utility)
vim.api.nvim_buf_delete(next_buffer, { force = true })
vim.wait(250)
assert(vim.api.nvim_win_get_buf(utility_win) == utility, "Switcher release overwrote a utility pane")
if #vim.api.nvim_tabpage_list_wins(0) > 1 then vim.api.nvim_win_close(utility_win, true)
else vim.api.nvim_win_set_buf(utility_win, buffers[6]) end
local cwd = vim.fn.getcwd()
local target = directory .. "/.config/nested/target%.txt"
vim.fn.writefile({ "breadcrumb target" }, target)
local source = vim.api.nvim_get_current_win()
local menu = require("ui.breadcrumbs").browse(directory, source)
local function item(label)
  for _, entry in ipairs(menu.items) do if entry.label:find(label, 1, true) then return entry end end
end
assert(vim.wait(2000, function() return item(".config") end, 10), "Hidden directory isn't listed")
item(".config").action(menu)
assert(vim.wait(2000, function() return item("nested") end, 10))
item("nested").action(menu)
assert(vim.wait(2000, function() return item("target%.txt") end, 10))
item("target%.txt").action(menu)
assert(vim.api.nvim_buf_get_name(0) == target and vim.fn.getcwd() == cwd, vim.api.nvim_buf_get_name(0) .. " ~= " .. target)
local rendered = require("ui.breadcrumbs").render(vim.api.nvim_get_current_buf(), 300)
assert(rendered and rendered:find(".config", 1, true) and rendered:find("target%%.txt", 1, true), "Breadcrumbs aren't escaped/rendered")
local tiny = require("ui.breadcrumbs").render(vim.api.nvim_get_current_buf(), 40)
assert(tiny and #tiny > 0)
assert(vim.bo[buffers[9]].modified, "Path navigation lost an unsaved buffer")
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Workspace: bold ordinal suffixes, numbered jumps, stable ordering, release-driven MRU cycling, hidden-directory menus, escaping and unsaved buffers passed"
