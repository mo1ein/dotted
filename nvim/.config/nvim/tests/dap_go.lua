-- Real Delve/DAP integration: launch, verified breakpoints, scopes, and stepping.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
for _, file in ipairs { "go.mod", "main.go", "main_test.go" } do
  vim.fn.writefile(vim.fn.readfile(root .. "/tests/fixtures/go-debug/" .. file), directory .. "/" .. file)
end
require("lazy").load { plugins = { "nvim-dap" } }
local dap = require "dap"
dap.set_log_level "DEBUG"
local stopped, terminated = 0, 0
local launch_error, output
dap.listeners.after.launch.owned_test = function(_, err) if err then launch_error = tostring(err) end end
dap.listeners.after.event_output.owned_test = function(_, body) output = (output or "") .. (body.output or "") end
dap.listeners.after.event_stopped.owned_test = function() stopped = stopped + 1 end
dap.listeners.after.event_terminated.owned_test = function() terminated = terminated + 1 end
local function wait(predicate, message)
  local completed = vim.wait(90000, function() return launch_error or predicate() end, 20)
  assert(not launch_error, tostring(launch_error) .. "\n" .. (output or ""))
  assert(completed, message .. " (see :DapShowLog)")
end
local function request(command, args)
  local done, result, failure = false
  dap.session():request(command, args, function(err, body) failure, result, done = err, body, true end)
  wait(function() return done end, "DAP request timed out: " .. command)
  assert(not failure, vim.inspect(failure))
  return result
end
local function frame() return dap.session() and dap.session().current_frame end
local function stopped_after(previous)
  wait(function() return stopped > previous and frame() and frame().scopes end, "Debugger didn't stop with scopes")
end
local function evaluate(expression)
  return request("evaluate", { expression = expression, frameId = frame().id, context = "watch" }).result
end
local function marker(file, text)
  for i, line in ipairs(vim.fn.readfile(directory .. "/" .. file)) do if line:find(text, 1, true) then return i end end
  error("Missing breakpoint marker")
end
local function configuration(name)
  for _, cfg in ipairs(dap.configurations.go) do if cfg.name == name then return vim.deepcopy(cfg) end end
  error("Missing launch configuration: " .. name)
end
vim.cmd.edit(vim.fn.fnameescape(directory .. "/main.go"))
local buf = vim.api.nvim_get_current_buf()
local line = marker("main.go", "BREAKPOINT_MAIN")
vim.api.nvim_win_set_cursor(0, { line, 0 })
dap.toggle_breakpoint()
dap.run(configuration "Go: current package")
stopped_after(0)
assert(frame().line == line and evaluate("value") == "21", "Main breakpoint/variable evaluation failed")
assert(require("dap.breakpoints").get(buf)[buf][1].state.verified, "Delve rejected the breakpoint")
local scopes = request("scopes", { frameId = frame().id }).scopes
local found = false
for _, scope in ipairs(scopes) do
  for _, variable in ipairs(request("variables", { variablesReference = scope.variablesReference }).variables) do
    if variable.name == "value" and variable.value == "21" then found = true end
  end
end
assert(found, "Variable inspection didn't return local value")
local session = dap.session()
vim.api.nvim_win_close(require("dapui.windows").layouts[1].opened_wins[1], true)
require("ui.dap").open()
assert(dap.session() == session and evaluate("value") == "21", "Pane recovery changed the paused Go session")
require("ui.tools").show("Debug")
require("ui.tools").hide()
assert(dap.session() == session and evaluate("value") == "21", "Closing Debug drawer changed the Go session")
local previous = stopped
dap.step_into()
stopped_after(previous)
assert(frame().name:find("double", 1, true), "Step into didn't enter double")
previous = stopped
dap.step_over()
stopped_after(previous)
-- Delve may initially stop on the function prologue; step to the return line.
if frame().line < 7 then previous = stopped; dap.step_over(); stopped_after(previous) end
assert(evaluate("result") == "42", "Step over didn't compute result")
previous = stopped
dap.step_out()
stopped_after(previous)
if frame().line < marker("main.go", "BREAKPOINT_AFTER") then previous = stopped; dap.step_over(); stopped_after(previous) end
assert(evaluate("result") == "42", "Step out lost the caller result")
dap.clear_breakpoints()
dap.continue()
wait(function() return terminated > 0 and not dap.session() end, "Program didn't terminate")

vim.cmd.edit(vim.fn.fnameescape(directory .. "/main.go"))
vim.api.nvim_win_set_cursor(0, { line, 0 })
dap.toggle_breakpoint()
previous = stopped
dap.run(configuration "Go: current file")
stopped_after(previous)
assert(evaluate("value") == "21", "Single-file launch failed")
dap.clear_breakpoints()
dap.continue()
wait(function() return terminated > 1 and not dap.session() end, "Single-file launch didn't terminate")

vim.cmd.edit(vim.fn.fnameescape(directory .. "/main_test.go"))
vim.api.nvim_win_set_cursor(0, { marker("main_test.go", "BREAKPOINT_TEST"), 0 })
dap.toggle_breakpoint()
previous = stopped
dap.run(configuration "Go: tests in package")
stopped_after(previous)
assert(evaluate("got") == "6", "Go test launch/variable inspection failed")
dap.clear_breakpoints()
dap.continue()
wait(function() return terminated > 2 and not dap.session() end, "Go test didn't terminate")
assert(vim.fn.sign_getdefined("DapBreakpoint")[1].text:find("●", 1, true))
dap.listeners.after.event_stopped.owned_test = nil
dap.listeners.after.event_terminated.owned_test = nil
dap.listeners.after.launch.owned_test = nil
dap.listeners.after.event_output.owned_test = nil
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Delve: file/package/test launches, verified breakpoints, local scopes, evaluate, step into/over/out, and exit passed"
vim.cmd "qa!"
