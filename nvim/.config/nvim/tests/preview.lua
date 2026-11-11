-- Dependency-free tests for debounced preview, cancellation, commit, and cleanup.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local preview = require "themes.preview"
local current, calls = "original", {}
local loader = {
  current = function() return current end,
  apply = function(name, remember, background)
    current = name
    calls[#calls + 1] = { name, remember, background }
    return true
  end,
}
local session = preview.new(loader, false, 20)
session.hover("a")
session.hover("b")
assert(vim.wait(200, function() return current == "b" end, 5))
assert(#calls == 1, "Fast navigation loaded intermediate themes")
session.hover("a")
session.finish()
vim.wait(50)
assert(current == "original" and #calls == 2, "Cancel didn't restore the original or a queued preview ran late")
session.finish() -- cleanup is idempotent

calls = {}
session = preview.new(loader, true, 20)
session.hover("a")
session.stop() -- fzf closes before invoking Enter's action
session.finish("b")
vim.schedule(function() session.finish() end)
vim.wait(50)
assert(current == "b" and #calls == 1 and calls[1][2] == true, "Enter didn't save or was undone by on_close")

local hovered, accepted
local popup = require("ui.theme_picker").open({ "first", "second" }, {
  hover = function(name) hovered = name end,
  select = function(name) accepted = name end,
  finish = function() end, stop = function() end, cancel_if_idle = function() end,
})
vim.api.nvim_win_set_cursor(popup.win, { 2, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = popup.buf })
assert(hovered == "second")
vim.fn.maparg("<CR>", "n", false, true).callback()
assert(accepted == "second" and not vim.api.nvim_win_is_valid(popup.win))

calls, current = {}, "original"
session = preview.new(loader, true, 20)
local answer
session.choose("candidate", function(_, callback) answer = callback end)
session.cancel_if_idle() -- the picker's queued on_close must not cancel the box
assert(current == "candidate" and #calls == 1 and not calls[1][2])
answer(false)
assert(current == "original" and #calls == 2)
calls = {}
session = preview.new(loader, true, 20)
session.choose("confirmed", function(_, callback) answer = callback end)
assert(#calls == 1 and not calls[1][2], "Candidate saved before confirmation")
answer(true)
assert(current == "confirmed" and #calls == 2 and calls[2][2] == true)
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Preview: debounce, cancellation, confirmation/save, close ordering, and native navigation passed"
