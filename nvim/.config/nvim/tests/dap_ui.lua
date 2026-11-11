-- Real dap-ui windows: partial layouts, repeated events, toggles, and user buffers.
require("lazy").load { plugins = { "nvim-dap" } }
local dap, dapui = require "dap", require "dapui"
local windows = require "dapui.windows"
local source_win, source_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, { "unsaved source must survive" })
local function initialized() dap.listeners.after.event_initialized.dapui_config() end
local function complete()
  for _, layout in ipairs(windows.layouts) do
    for index in ipairs(layout.win_states) do
      local win = layout.opened_wins[index]
      assert(win and vim.api.nvim_win_is_valid(win), "Debug pane was not reopened")
      assert(vim.api.nvim_win_get_buf(win) == layout.win_bufs[win](), "Wrong debug buffer")
    end
  end
end
local function closed()
  for _, layout in ipairs(windows.layouts) do
    assert(not layout:is_open(), "Debug layout stayed open")
    assert(next(layout.win_bufs) == nil, "Closed layout retained stale buffer callbacks")
  end
end
initialized()
complete()
local scopes = dapui.elements.scopes.buffer()
local watches = dapui.elements.watches.buffer()
dapui.elements.watches.add "owned_ui_watch"

-- This reproduces layout.lua:106 (first pane) and :114 (another pane).
for _, index in ipairs { 1, 2, 4 } do
  vim.api.nvim_win_close(windows.layouts[1].opened_wins[index], true)
  initialized()
  complete()
  assert(dapui.elements.scopes.buffer() == scopes, "Recovery reset debugger elements")
  assert(dapui.elements.watches.buffer() == watches, "Recovery replaced watches")
end
local ui = require "ui.dap"
ui.setup(dap)
assert(dapui.elements.watches.get()[1].expression == "owned_ui_watch", "Setup cleared watch expressions")
assert(dapui.elements.scopes.buffer() == scopes, "Repeated setup replaced elements")
for _ = 1, 3 do
  initialized()
  complete()
  assert(vim.api.nvim_get_current_win() == source_win, "Auto-open stole source focus")
  vim.api.nvim_win_close(windows.layouts[2].opened_wins[1], true)
  ui.open()
  complete()
  vim.api.nvim_win_close(windows.layouts[1].opened_wins[1], true)
  require("keymaps.actions")["debug.ui"].rhs()
  closed()
  require("keymaps.actions")["debug.ui"].rhs()
  complete()
  vim.api.nvim_win_close(windows.layouts[1].opened_wins[2], true)
  dap.listeners.before.event_terminated.dapui_config()
  dap.listeners.before.event_exited.dapui_config()
  closed()
end

-- :only/manual closure can remove all tracked panes, not just one.
initialized()
vim.api.nvim_set_current_win(source_win)
vim.cmd "only"
initialized()
complete()
ui.close()
closed()

-- A window repurposed for a user's modified buffer must not be force-closed.
initialized()
local user_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(user_buf, 0, -1, false, { "unsaved work in a former debug pane" })
local user_win = windows.layouts[1].opened_wins[1]
local eventignore = vim.o.eventignore
vim.o.eventignore = "all"
vim.api.nvim_win_set_buf(user_win, user_buf)
vim.o.eventignore = eventignore
ui.open()
complete()
ui.close()
closed()
assert(vim.api.nvim_win_is_valid(user_win), "Recovery closed a user window")
assert(vim.api.nvim_win_get_buf(user_win) == user_buf, "Recovery replaced a user buffer")
assert(vim.bo[user_buf].modified and vim.api.nvim_buf_get_lines(user_buf, 0, -1, false)[1] == "unsaved work in a former debug pane")
assert(vim.api.nvim_win_is_valid(source_win) and vim.api.nvim_win_get_buf(source_win) == source_buf)
assert(vim.bo[source_buf].modified)
assert(dapui.elements.watches.buffer() == watches)
assert(dapui.elements.watches.get()[1].expression == "owned_ui_watch", "Recovery cleared watch expressions")
assert(vim.v.errmsg == "", vim.v.errmsg)
print "DAP UI: partial-pane recovery, auto-open, toggles, repeated termination, focus and unsaved buffers passed"
