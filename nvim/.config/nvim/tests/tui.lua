-- Native TUI checks: dashboard safety, clickable buffers, and retained statusline.
local statusline = vim.o.statusline
local theme = require("config.theme_loader").current()
local file = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(file, vim.fn.tempname() .. "100%.txt")
vim.api.nvim_buf_set_lines(file, 0, -1, false, { "keep my unsaved edits" })
vim.api.nvim_set_current_buf(file)
local dashboard = require("ui.dashboard").open()
assert(vim.bo[dashboard.buf].filetype == "dashboard" and not vim.bo[dashboard.buf].buflisted)
assert(vim.api.nvim_buf_get_lines(file, 0, 1, false)[1] == "keep my unsaved edits" and vim.bo[file].modified)
assert(vim.o.statusline == statusline and require("config.theme_loader").current() == theme)
local tabline = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = 160 }).str
assert(tabline:find("100%.txt", 1, true), "Buffer filename wasn't escaped safely")
_G.DottedBufferClick(file, 1, "l")
assert(vim.api.nvim_get_current_buf() == file)
assert(vim.wo.number and vim.wo.signcolumn == "yes", "Dashboard settings leaked into the file window")
local notify, warned = vim.notify, false
vim.notify = function() warned = true end
_G.DottedBufferClose(file)
vim.notify = notify
assert(warned and vim.api.nvim_buf_is_valid(file) and vim.bo[file].modified, "Bufferline discarded modified text")
assert(vim.v.errmsg == "", vim.v.errmsg)
vim.bo[file].modified = false
_G.DottedBufferClose(file)
assert(not vim.bo[file].buflisted)
vim.cmd "Dashboard"
local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(content:find("Find file", 1, true) and content:find("Recent files", 1, true))
vim.api.nvim_exec_autocmds("VimResized", {})
assert(vim.o.tabline:find("ui.bufferline", 1, true) and vim.o.showtabline == 2)
assert(vim.v.errmsg == "", vim.v.errmsg)
print "TUI: dashboard actions, unsaved-file safety, clickable buffer tabs, percent escaping, resize, and original statusline/theme passed"
vim.cmd "qa!"
