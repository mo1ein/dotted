-- Dependency-free checks for the actual confirmation box and its safe default.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local confirm = require "ui.confirm"
local answer
local popup = confirm.open('Use "example"?', function(value) answer = value end)
assert(vim.bo[popup.buf].filetype == "theme-confirm")
vim.fn.maparg("<CR>", "n", false, true).callback()
assert(answer == false and not vim.api.nvim_win_is_valid(popup.win), "Default confirmation should be No")
popup = confirm.open('Use "example"?', function(value) answer = value end)
vim.fn.maparg("<Left>", "n", false, true).callback()
vim.fn.maparg("<CR>", "n", false, true).callback()
assert(answer == true and not vim.api.nvim_win_is_valid(popup.win))
popup = confirm.open('Use "example"?', function(value) answer = value end)
vim.fn.maparg("<Esc>", "n", false, true).callback()
assert(answer == false)
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Confirmation: floating box, safe No default, Yes/Enter, and Escape passed"
