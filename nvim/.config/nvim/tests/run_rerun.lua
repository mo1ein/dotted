-- Rerun retains command/cwd/interpreter after switching files, tabs and projects.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p");dir = assert(vim.uv.fs_realpath(dir))
local a, b = dir .. "/project A", dir .. "/project B"
vim.fn.mkdir(a, "p"); vim.fn.mkdir(b, "p")
local python = assert(require("configs.dap_python").adapter_python())
for _, root in ipairs { a, b } do
  local result = vim.system({ python, "-m", "venv", "--without-pip", root .. "/.venv" }, { text = true }):wait(30000)
  assert(result.code == 0, result.stderr)
end
local interpreter = a .. "/.venv/bin/python"
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = nil, nil
vim.fn.writefile({ "import sys", "print('A_FILE',sys.executable,flush=True)", "value = 21", "print('A_END',flush=True)" }, a .. "/main.py")
vim.fn.writefile({ "import os", "print('A_PROJECT',os.environ['RUN_CONFIGURATION'],flush=True)" }, a .. "/project.py")
vim.fn.writefile({ "print('B_FILE',flush=True)" }, b .. "/other.py")
vim.fn.writefile({ "print('B_PROJECT',flush=True)" }, b .. "/project.py")
vim.fn.writefile({}, a .. "/uv.lock")
-- A working uv environment should not be re-synced for every script launch.
vim.fn.mkdir(dir .. "/bin", "p")
local uv_called = dir .. "/uv-was-called"
vim.fn.writefile({ "#!/bin/sh", "touch " .. vim.fn.shellescape(uv_called), "exit 1" }, dir .. "/bin/uv")
vim.fn.setfperm(dir .. "/bin/uv", "rwxr-xr-x")
vim.env.PATH = dir .. "/bin:" .. vim.env.PATH
vim.cmd.edit(vim.fn.fnameescape(a .. "/main.py"))
local source_a, tab_a = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_tabpage()
require("lazy").load { plugins = { "conform.nvim" } }
local formatted = dir .. "/formatted"
require("conform").setup {
  formatters = { slow_launch_test = { command = python, args = { "-c", "import sys,time;time.sleep(.6);open(sys.argv[1],'a').write('formatted\\n');sys.stdout.write(sys.stdin.read())", formatted }, stdin = true } },
  formatters_by_ft = { python = { "slow_launch_test" } },
  format_on_save = require("configs.conform").format_on_save,
}
vim.api.nvim_buf_set_lines(source_a, -1, -1, false, { "# unsaved change" })
local started = vim.uv.hrtime()
local task = require("util.run").file()
local launch_ms = (vim.uv.hrtime() - started) / 1e6
assert(task and launch_ms < 400, "Run blocked on formatting: " .. launch_ms .. "ms")
assert(vim.fn.filereadable(formatted) == 0, "Run invoked format-on-save")
assert(vim.fn.filereadable(uv_called) == 0, "Run re-synced an existing uv environment")
assert(type(task.cmd) == "table" and task.cmd[1] == interpreter, "Run went through shell/uv instead of the pinned interpreter: " .. vim.inspect(task.cmd) .. " expected " .. interpreter)
local function text(t) local buf = t:get_bufnr();return buf and table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),"\n") or "" end
local function finish(t, marker)
  assert(vim.wait(15000, function() return t:is_complete() and text(t):find(marker,1,true) ~= nil end, 5), text(t))
end
finish(task, "A_END")
require("ui.tools").hide()
vim.api.nvim_buf_set_lines(source_a, 1, 2, false, { "print('A_UPDATED',__import__('sys').executable,flush=True)" })
vim.cmd.tabnew(vim.fn.fnameescape(b .. "/other.py"))
local source_b, win_b, tab_b = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win(), vim.api.nvim_get_current_tabpage()
vim.api.nvim_buf_set_lines(source_b, 0, -1, false, { "print('B_UNSAVED')" })
vim.cmd.lcd(vim.fn.fnameescape(b))
require("ui.run_toolbar").action(7)
finish(task, "A_UPDATED")
assert(task.cmd[2] == a .. "/main.py" and task.cwd == a and text(task):gsub("\n", ""):find(interpreter,1,true), vim.inspect {cmd=task.cmd,cwd=task.cwd,expected=a,output=text(task)})
assert(vim.bo[source_b].modified and vim.fn.readfile(b .. "/other.py")[1]:find("B_FILE",1,true), "Rerun saved the other tab")
assert(vim.api.nvim_get_current_tabpage() == tab_b and vim.api.nvim_win_get_buf(win_b) == source_b, "Rerun hijacked the source tab")
assert(vim.fn.filereadable(formatted) == 0, "Rerun formatted the wrong source")
require("ui.tools").hide()
-- The original source can even be closed; its executable target stays valid.
vim.api.nvim_buf_delete(source_a, { force = false })
require("ui.run_toolbar").action(7)
finish(task, "A_UPDATED")
require("ui.tools").hide()
-- Project commands keep their original relative arguments and working directory.
if vim.api.nvim_tabpage_is_valid(tab_a) then vim.api.nvim_set_current_tabpage(tab_a)
else vim.cmd.tabnew(); tab_a = vim.api.nvim_get_current_tabpage() end
vim.cmd.edit(vim.fn.fnameescape(a .. "/main.py"))
source_a = vim.api.nvim_get_current_buf()
vim.cmd.lcd(vim.fn.fnameescape(a))
local project = require("util.run").start { name = "Project A", command = { interpreter, "project.py" }, cwd = ".", env = { RUN_CONFIGURATION = "ORIGINAL_A" } }
finish(project, "A_PROJECT")
require("ui.tools").hide()
vim.api.nvim_set_current_tabpage(tab_b)
vim.env.RUN_CONFIGURATION = "OTHER_B"
require("ui.run_toolbar").action(7)
finish(project, "ORIGINAL_A")
assert(project.cwd == a and not text(project):find("B_PROJECT",1,true))
require("ui.tools").hide()
-- An ordinary save still formats; only launching bypasses the formatter wait.
vim.api.nvim_set_current_win(win_b)
vim.cmd.update()
assert(vim.fn.filereadable(formatted) == 1, "Normal save lost format-on-save")
-- Debugger restart and Run Last use resolved config, never the newly focused file.
vim.api.nvim_set_current_tabpage(tab_a)
vim.cmd.edit(vim.fn.fnameescape(a .. "/main.py"))
local dap = require "dap"
local stops, ends = 0, 0
dap.listeners.after.event_stopped.rerun_test = function() stops = stops + 1 end
dap.listeners.after.event_terminated.rerun_test = function() ends = ends + 1 end
vim.api.nvim_win_set_cursor(0, {3,0});dap.toggle_breakpoint()
require("ui.run_toolbar").action(9)
local function stopped(previous)
  assert(vim.wait(45000, function()
    local s = dap.session()
    return stops > previous and s and s.stopped_thread_id and s.current_frame and s.current_frame.scopes
  end, 20), "Debugger didn't stop")
  local s = dap.session()
  assert(s.config.program == a .. "/main.py" and s.config.cwd == a, vim.inspect(s.config))
  assert(s.current_frame.source.path == a .. "/main.py", vim.inspect(s.current_frame))
  assert(s.config.python[1] == interpreter, "Restart selected the other project's Python")
end
stopped(0)
local previous = stops
vim.api.nvim_set_current_tabpage(tab_b)
vim.env.VIRTUAL_ENV = b .. "/.venv"
require("ui.run_toolbar").action(7)
stopped(previous)
-- Let it finish, then rerun from a different project and different filetype.
dap.clear_breakpoints();dap.continue()
assert(vim.wait(15000, function() return ends > 0 and dap.session() == nil end, 20))
assert(require("ui.run_toolbar").mode == "debug", "Finished debug selection was lost")
vim.api.nvim_set_current_tabpage(tab_b)
vim.bo[source_b].filetype = "lua"
-- Keep the original breakpoint even though the source is not the focused tab.
require("dap.breakpoints").set({}, source_a, 3)
previous = stops
require("ui.run_toolbar").action(7)
stopped(previous)
dap.clear_breakpoints();dap.continue()
assert(vim.wait(15000, function() return dap.session() == nil end, 20))
vim.api.nvim_set_current_tabpage(tab_b)
require("dap.breakpoints").set({}, source_a, 3)
previous = stops
require("util.debug_session").restart() -- same action as Space d l
stopped(previous)
dap.terminate()
assert(vim.wait(15000, function() return dap.session() == nil end, 20))
assert(vim.v.errmsg == "", vim.v.errmsg)
print(("Rerun: file/project target and cwd stay pinned across tabs/closed buffers; debug restart and Run Last retain file/interpreter; launch skips 600ms formatter (%.0fms handler), regular save still formats"):format(launch_ms))
