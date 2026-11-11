-- Actual tool providers, process persistence, and window ownership regressions.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
vim.o.columns = 180
local tools = require "ui.tools"
local source = vim.api.nvim_get_current_win()
local file = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(file)
vim.api.nvim_buf_set_lines(file, 0, -1, false, { "unsaved editor text" })
tools.show("Terminal")
local terminal = tools.current().buf
local job = vim.b[terminal].terminal_job_id
assert(job and vim.bo[terminal].buftype == "terminal")
vim.fn.chansend(job, "echo DOTTED_TERMINAL_OK\n")
assert(vim.wait(3000, function() return table.concat(vim.api.nvim_buf_get_lines(terminal, 0, -1, false), "\n"):find("DOTTED_TERMINAL_OK", 1, true) end, 10))
local header = vim.api.nvim_eval_statusline(tools.header(), { use_winbar = true, winid = tools.current().win, maxwidth = 180 }).str
for _, tab in ipairs { "Debug", "Output", "Problems", "Terminal" } do assert(header:find(tab, 1, true), header) end
tools.minimize()
assert(vim.api.nvim_win_get_height(tools.current().win) <= 2)
tools.minimize()
assert(vim.api.nvim_win_get_height(tools.current().win) > 1)
tools.hide()
assert(not tools.is_open() and vim.fn.jobwait({ job }, 0)[1] == -1, "Hiding killed the shell")
tools.show("Terminal")
assert(tools.current().buf == terminal, "Terminal wasn't reused")
_G.DottedBufferClick(file, 1, "l")
assert(vim.api.nvim_get_current_win() == source and tools.current().buf == terminal, "Tab click hijacked the drawer")
tools.show("Output")
local task = require("ui.output").run { "sh", "-c", "printf 'DOTTED_OUTPUT_OK\\n'; printf 'DOTTED_STDERR_OK\\n' >&2" }
assert(vim.wait(5000, function() return task:is_complete() end, 10), "Output task didn't exit")
local output = table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), "\n")
assert(output:find("DOTTED_OUTPUT_OK", 1, true) and output:find("DOTTED_STDERR_OK", 1, true), output)
assert(tools.current().buf == task:get_bufnr())
local output_win = tools.current().win
require("ui.output").restart()
assert(vim.wait(5000, function() return task:is_complete() end, 10))
assert(tools.is_open() and tools.current().buf == task:get_bufnr(), "Rerun detached the output window")
assert(tools.current().win == output_win, "Rerun rebuilt the drawer")
tools.hide()
assert(task:get_bufnr(), "Hiding disposed task output")
vim.api.nvim_set_current_win(source)
local ns = vim.api.nvim_create_namespace "dotted-tools-test"
vim.diagnostic.set(ns, file, { { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "DOTTED_PROBLEM" } })
tools.show("Problems")
assert(vim.wait(5000, function() return tools.is_open() end, 10), "Problems didn't mount")
assert(vim.wait(3000, function() return table.concat(vim.api.nvim_buf_get_lines(tools.current().buf, 0, -1, false), "\n"):find("DOTTED_PROBLEM", 1, true) end, 10), "Problems didn't show diagnostics")
tools.show("Terminal")
assert(tools.current().buf == terminal)
tools.show("Debug")
assert(require("dap").configurations.python)
tools.hide()
for _ = 1, 3 do tools.show("Problems"); tools.show("Terminal"); tools.hide() end
vim.wait(500)
assert(not tools.is_open(), "Late async refresh reopened the drawer")
for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  assert(not vim.w[win].dotted_tool, "Rapid tab switches leaked a drawer window")
end
tools.show("Terminal")
local repurposed = tools.current().win
local user = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(user, 0, -1, false, { "more unsaved work" })
vim.api.nvim_win_set_buf(repurposed, user)
tools.hide()
assert(vim.api.nvim_win_is_valid(repurposed) and vim.api.nvim_win_get_buf(repurposed) == user, "Drawer closed a repurposed user window")
assert(vim.bo[user].modified and vim.bo[file].modified)
assert(vim.api.nvim_win_is_valid(source) and vim.api.nvim_win_get_buf(source) == file)
vim.fn.jobstop(job)
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Tools: tabs, real shell, stdout/stderr, live diagnostics, minimize/restore, rapid switching and unsaved-window safety passed"
