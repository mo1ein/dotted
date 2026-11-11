-- Run-file integration uses real executables and quoted paths in disposable files.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local directory = vim.fn.tempname() .. " runner '100%"
vim.fn.mkdir(directory, "p")
local file = directory .. "/hello '100%.py"
vim.fn.writefile({ "import sys", "print('PYTHON_RUNNER_OK')", "print('PYTHON_STDERR_OK', file=sys.stderr)" }, file)
vim.cmd.edit(vim.fn.fnameescape(file))
require("util.run_file")()
local task = require("ui.output").selected
assert(task and vim.wait(10000, function() return task:is_complete() end, 10))
local output = table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), "\n")
assert(task.exit_code == 0 and output:find("PYTHON_RUNNER_OK", 1, true) and output:find("PYTHON_STDERR_OK", 1, true), output)
require("ui.tools").hide()
vim.fn.writefile({ "module example.test/runner", "", "go 1.23" }, directory .. "/go.mod")
vim.fn.writefile({ "package main", "import \"fmt\"", "func main() { fmt.Println(message()) }" }, directory .. "/main.go")
vim.fn.writefile({ "package main", "func message() string { return \"GO_PACKAGE_RUNNER_OK\" }" }, directory .. "/helper.go")
vim.cmd.edit(vim.fn.fnameescape(directory .. "/main.go"))
require("util.run_file")()
task = require("ui.output").selected
assert(task and vim.wait(45000, function() return task:is_complete() end, 20))
output = table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), "\n")
assert(task.exit_code == 0 and output:find("GO_PACKAGE_RUNNER_OK", 1, true), output)
require("ui.tools").hide()
local waiting = require("ui.output").run { "sh", "-c", "printf 'WAITING_FOR_INPUT\\n'; read answer; printf '%s\\n' \"$answer\"" }
assert(waiting:is_running())
require("ui.tools").hide()
assert(waiting:is_running(), "Hiding Output stopped its process")
require("ui.output").stop()
assert(vim.wait(5000, function() return not waiting:is_running() end, 10), "Explicit Stop didn't stop the task")
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Output runner: real Python stdout/stderr, spaces/quotes/percent paths, Go package dependencies, hide persistence and explicit Stop passed"
