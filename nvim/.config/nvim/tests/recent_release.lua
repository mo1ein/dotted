-- Exercise the actual state-polling lifecycle with a controlled modifier source.
-- Terminal bytes cannot synthesize a physical macOS modifier release.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local registry, switcher, modifiers = require "ui.buffers", require "ui.switcher", require "ui.modifiers"
local actual = modifiers.is_down("alt")
if vim.fn.has("macunix") == 1 and not vim.env.SSH_CONNECTION and not vim.env.SSH_TTY then
  assert(type(actual) == "boolean", "Native CoreGraphics modifier query unavailable")
end
local held = true
modifiers.is_down = function() return held end
for _, buf in ipairs(registry.list()) do vim.bo[buf].buflisted = false end
local files = {}
for index = 1, 4 do
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. ".txt")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved " .. index, "second line" })
  files[index] = buf
  vim.api.nvim_set_current_buf(buf)
end
local source = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_cursor(source, { 2, 3 })
local original_view = vim.fn.winsaveview()
local recent, windows = registry.recent(), vim.api.nvim_list_wins()
local escape_before = vim.fn.maparg("<Esc>", "i", false, true)
switcher.cycle("next")
assert(vim.api.nvim_get_current_buf() == recent[2])
local first = switcher.current()
assert(first and not vim.api.nvim_win_get_config(first.win).focusable)
vim.wait(1100) -- beyond the old inactivity timeout
assert(switcher.current() == first, "Held Option timed out")
assert(vim.deep_equal(registry.recent(), recent), "Preview changed MRU")
switcher.cycle("next")
assert(vim.api.nvim_get_current_buf() == recent[3])
switcher.cycle("prev")
assert(vim.api.nvim_get_current_buf() == recent[2])
held = false
assert(vim.wait(500, function() return not switcher.current() end, 1), "Release did not dismiss")
assert(vim.api.nvim_get_current_buf() == recent[2] and registry.recent()[1] == recent[2])
assert(vim.deep_equal(windows, vim.api.nvim_list_wins()), "Release changed split layout")
held = true
vim.api.nvim_set_current_buf(files[4])
vim.fn.winrestview(original_view)
switcher.cycle("next")
vim.api.nvim_feedkeys(vim.keycode "<Esc>", "xt", false)
assert(vim.wait(500, function() return not switcher.current() end, 1), "Escape didn't cancel")
assert(vim.api.nvim_get_current_buf() == files[4], "Cancel didn't restore original")
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 2, 3 }), "Cancel lost cursor")
switcher.cycle("next")
vim.api.nvim_feedkeys(vim.keycode "<CR>", "xt", false)
assert(vim.wait(500, function() return not switcher.current() end, 1), "Enter didn't confirm")
assert(vim.deep_equal(escape_before, vim.fn.maparg("<Esc>", "i", false, true)), "Switcher overwrote insert mappings")
switcher.cycle("next")
vim.api.nvim_exec_autocmds("FocusLost", {})
assert(not switcher.current(), "Focus loss left watcher/popup alive")
switcher.cycle("next")
local stale = switcher.current()
vim.cmd "botright new"
local utility, utility_win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
assert(not switcher.current(), "Window change left popup alive")
held = false
vim.wait(30)
assert(vim.api.nvim_win_get_buf(utility_win) == utility, "Late release overwrote utility")
vim.api.nvim_win_close(utility_win, true)
vim.api.nvim_set_current_win(source)
held = true
switcher.cycle("next")
local deletion = switcher.current().buffers[1]
vim.api.nvim_buf_delete(deletion, { force = true })
assert(not switcher.current(), "Deleting snapshot candidate didn't clean up")
assert(not vim.api.nvim_win_is_valid(stale.win), "Stale popup survived")
-- Unsupported/remote systems still have no timeout and explicit confirmation.
modifiers.is_down = function() return nil end
switcher.cycle("next")
assert(switcher.current() and not switcher.current().stop)
switcher.finish()
-- External popup closure must not recurse or leak a watcher/scratch buffer.
held = true
modifiers.is_down = function() return held end
switcher.cycle("next")
local external = switcher.current()
vim.api.nvim_win_close(external.win, true)
assert(not switcher.current() and not vim.api.nvim_buf_is_valid(external.buf), "External close leaked popup state")
switcher.cycle("next")
vim.api.nvim_feedkeys("l", "xt", false)
assert(vim.wait(500, function() return not switcher.current() end, 1), "Other input didn't confirm")
for _, buf in ipairs(files) do
  if vim.api.nvim_buf_is_valid(buf) then assert(vim.bo[buf].modified, "Lost unsaved edits") end
end
assert(not registry.suspend_touch and vim.v.errmsg == "", vim.v.errmsg)
print "Recent release: native flags available; simulated hold/release, reverse, Esc/Enter, focus/deletion cleanup, fallback, layout and unsaved buffers passed"
