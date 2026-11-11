-- Real debugpy: isolated adapter, project venv, verified breakpoint, steps, unittest.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
require("lazy").load { plugins = { "nvim-dap" } }
local dap, python = require "dap", require "configs.dap_python"
local adapter = assert(python.adapter_python(), "Install debugpy before running this test")
local directory = vim.fn.tempname() .. " python project"
vim.fn.mkdir(directory, "p")
directory = assert(vim.uv.fs_realpath(directory))
for _, file in ipairs { "main.py", "test_main.py" } do
  vim.fn.writefile(vim.fn.readfile(root .. "/tests/fixtures/python-debug/" .. file), directory .. "/" .. file)
end
local venv = directory .. "/.venv"
local created = vim.system({ adapter, "-m", "venv", "--without-pip", venv }, { text = true }):wait(30000)
assert(created.code == 0, created.stderr)
local venv_python = venv .. "/bin/python"
local check = vim.system({ venv_python, "-c", "import importlib.util; assert importlib.util.find_spec('debugpy') is None" }, { text = true }):wait(10000)
assert(check.code == 0, "Project venv should not need debugpy installed")
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = nil, nil
local stopped, terminated, launch_error, output = 0, 0, nil, ""
dap.listeners.after.event_stopped.python_test = function() stopped = stopped + 1 end
dap.listeners.after.event_terminated.python_test = function() terminated = terminated + 1 end
dap.listeners.after.launch.python_test = function(_, err) if err then launch_error = tostring(err) end end
dap.listeners.after.event_output.python_test = function(_, body) output = output .. (body.output or "") end
local function wait(predicate, message)
  local ok = vim.wait(45000, function() return launch_error or predicate() end, 20)
  assert(not launch_error, tostring(launch_error) .. "\n" .. output)
  assert(ok, message .. "\n" .. output)
end
local function frame() return dap.session() and dap.session().current_frame end
local function stop_after(previous)
  wait(function() return stopped > previous and frame() and frame().scopes end, "Python didn't stop with scopes")
end
local function request(command, arguments)
  local done, failure, response = false
  dap.session():request(command, arguments, function(err, body) failure, response, done = err, body, true end)
  wait(function() return done end, "DAP request timed out: " .. command)
  assert(not failure, vim.inspect(failure))
  return response
end
local function evaluate(expression)
  return request("evaluate", { expression = expression, frameId = frame().id, context = "watch" }).result
end
local function marker(file, text)
  for i, line in ipairs(vim.fn.readfile(directory .. "/" .. file)) do if line:find(text, 1, true) then return i end end
  error("Missing Python fixture marker")
end
local function configuration(name)
  for _, cfg in ipairs(dap.configurations.python) do if cfg.name == name then return vim.deepcopy(cfg) end end
  error("Missing Python configuration: " .. name)
end
vim.cmd.edit(vim.fn.fnameescape(directory .. "/main.py"))
assert(python.interpreter() == venv_python, "Project .venv wasn't selected")
assert(dap.adapters.debugpy == dap.adapters.python, "VS Code debugpy alias is missing")
local source = vim.api.nvim_get_current_buf()
vim.api.nvim_win_set_cursor(0, { marker("main.py", "BREAKPOINT_MAIN"), 0 })
dap.toggle_breakpoint()
local editor = vim.api.nvim_get_current_win()
require("ui.tools").show("Debug")
vim.api.nvim_set_current_win(editor)
dap.run(configuration "Python: current file")
stop_after(0)
assert(require("ui.tools").current().buf == require("dapui").elements.console.buffer(), "Initialized event didn't refresh the open Debug drawer")
require("ui.tools").hide()
assert(evaluate("value") == "21")
assert(evaluate("__import__('sys').executable"):find(venv_python, 1, true), "Program isn't using the project's Python")
assert(require("dap.breakpoints").get(source)[source][1].state.verified)
local found = false
for _, scope in ipairs(request("scopes", { frameId = frame().id }).scopes) do
  for _, variable in ipairs(request("variables", { variablesReference = scope.variablesReference }).variables) do
    if variable.name == "value" and variable.value == "21" then found = true end
  end
end
assert(found, "Python local-variable inspection failed")
local session = dap.session()
vim.api.nvim_win_close(require("dapui.windows").layouts[1].opened_wins[1], true)
require("ui.dap").open()
assert(dap.session() == session and evaluate("value") == "21", "Pane recovery changed the paused Python session")
require("ui.tools").show("Debug")
assert(require("ui.tools").current().buf == require("dapui").elements.console.buffer(), "Drawer isn't using the real program console")
require("ui.tools").hide()
assert(dap.session() == session and evaluate("value") == "21", "Closing Debug drawer changed the Python session")
require("ui.dap").toggle()
require("ui.dap").toggle()
assert(evaluate("value") == "21", "UI toggle lost Python inspection")
local previous = stopped
dap.step_into()
stop_after(previous)
assert(frame().name == "double", "Step into didn't enter Python function")
previous = stopped
dap.step_over()
stop_after(previous)
assert(evaluate("result") == "42", "Python step over failed")
previous = stopped
dap.step_out()
stop_after(previous)
if frame().line < marker("main.py", "BREAKPOINT_AFTER") then previous = stopped; dap.step_over(); stop_after(previous) end
assert(evaluate("result") == "42", "Python step out failed")
dap.clear_breakpoints()
dap.continue()
wait(function() return terminated >= 1 and not dap.session() end, "Python program didn't exit")

vim.cmd.edit(vim.fn.fnameescape(directory .. "/test_main.py"))
vim.api.nvim_win_set_cursor(0, { marker("test_main.py", "BREAKPOINT_TEST"), 0 })
dap.toggle_breakpoint()
previous = stopped
dap.run(configuration "Python: unittest (current file)")
stop_after(previous)
assert(evaluate("got") == "6", "Python unittest launch failed")
dap.clear_breakpoints()
dap.continue()
wait(function() return terminated >= 2 and not dap.session() end, "Python unittest didn't exit")

-- Also verify a plain script without a project environment uses PATH Python.
assert(vim.uv.fs_rename(venv, venv .. "-disabled"))
vim.cmd.edit(vim.fn.fnameescape(directory .. "/main.py"))
local fallback = python.interpreter()
local identity = vim.system({ fallback, "-c", "import sys; print(sys.executable)" }, { text = true }):wait(10000)
assert(identity.code == 0)
vim.api.nvim_win_set_cursor(0, { marker("main.py", "BREAKPOINT_MAIN"), 0 })
dap.toggle_breakpoint()
previous = stopped
dap.run(configuration "Python: current file")
stop_after(previous)
assert(evaluate("value") == "21")
assert(evaluate("__import__('sys').executable"):find(vim.trim(identity.stdout), 1, true), "PATH interpreter wasn't used")
dap.clear_breakpoints()
dap.continue()
wait(function() return terminated >= 3 and not dap.session() end, "Plain Python script didn't exit")
dap.listeners.after.event_stopped.python_test = nil
dap.listeners.after.event_terminated.python_test = nil
dap.listeners.after.launch.python_test = nil
dap.listeners.after.event_output.python_test = nil
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Python: debugpy file/unittest launches, project venv and PATH interpreters, breakpoint, scopes, stepping, terminal and exit passed"
vim.cmd "qa!"
