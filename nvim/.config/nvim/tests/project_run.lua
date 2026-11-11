-- Launch whole disposable projects from library files using the real toolbar.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local dir = vim.fn.tempname() .. " project '100%"
vim.fn.mkdir(dir, "p")
dir = assert(vim.uv.fs_realpath(dir))
local a, b = dir .. "/app A", dir .. "/app B"
local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end
for _, root in ipairs { a, b } do
  write(root .. "/pyproject.toml", { "[project]", 'name="run-test"' })
  write(root .. "/lib/helper.py", { "print('CURRENT_FILE_ONLY', flush=True)" })
end
write(a .. "/main.py", { "from message import VALUE", "print('PROJECT_A', VALUE, flush=True)" })
write(a .. "/__main__.py", { "print('ALTERNATE_A', flush=True)" })
write(a .. "/message.py", { "VALUE = 'OLD'" })
write(b .. "/__main__.py", { "print('PROJECT_B', flush=True)" })
local outside = dir .. "/unrelated.py"
write(outside, { "print('UNRELATED_DISK')" })
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = nil, nil
vim.cmd.edit(vim.fn.fnameescape(a .. "/lib/helper.py"))
local win_a = vim.api.nvim_get_current_win()
local sibling = vim.fn.bufadd(a .. "/message.py")
vim.fn.bufload(sibling)
vim.api.nvim_buf_set_lines(sibling, 0, -1, false, { "VALUE = 'SAVED_SIBLING'" })
local unrelated = vim.fn.bufadd(outside)
vim.fn.bufload(unrelated)
vim.api.nvim_buf_set_lines(unrelated, 0, -1, false, { "print('UNRELATED_UNSAVED')" })
local run = require "util.run"
local function finish(task, marker)
  assert(task and vim.wait(15000, function()
    return task:is_complete()
  end, 10), "Project didn't finish")
  local output = table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), "\n")
  assert(task.exit_code == 0 and output:find(marker, 1, true), output)
  require("ui.tools").hide()
end
local function choose(menu, label)
  assert(menu and menu.items, "Expected a run-target menu")
  for _, item in ipairs(menu.items) do
    if item.label == "▶ " .. label then
      item.action(menu)
      return require("ui.output").selected
    end
  end
  error("Missing run target " .. label)
end
local menu = require("ui.run_toolbar").action(10)
local task = choose(menu, "Python: main.py")
finish(task, "PROJECT_A SAVED_SIBLING")
assert(task.cwd == a and task.metadata.dotted_project == a)
assert(not vim.bo[sibling].modified and vim.bo[unrelated].modified, "Project launch saved the wrong buffers")
vim.api.nvim_set_current_win(win_a)
task = require("ui.run_toolbar").action(10)
finish(task, "PROJECT_A SAVED_SIBLING")
assert(task.cwd == a, "Run forgot the selected project target")

-- Switching projects must not carry over the other project's target. Restart
-- still owns the selected project's buffers and working directory.
vim.cmd.tabnew(vim.fn.fnameescape(b .. "/lib/helper.py"))
local win_b = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_lines(sibling, 0, -1, false, { "VALUE = 'PROJECT_RESTART_SAVED'" })
require("ui.run_toolbar").action(7)
finish(task, "PROJECT_A PROJECT_RESTART_SAVED")
assert(vim.bo[unrelated].modified, "Restart saved another project's buffers")
vim.api.nvim_set_current_win(win_b)
task = require("ui.run_toolbar").action(10)
finish(task, "PROJECT_B")
assert(task.cwd == b)

-- File and project have separate controls and keys. Running another entry
-- file must never replace the application's selected project target.
vim.api.nvim_set_current_win(win_a)
task = require("ui.run_toolbar").action(1)
finish(task, "CURRENT_FILE_ONLY")
assert(task.metadata.dotted_project == nil)
vim.api.nvim_set_current_win(win_a)
vim.cmd.edit(vim.fn.fnameescape(a .. "/__main__.py"))
task = vim.fn.maparg(" r", "n", false, true).callback()
finish(task, "ALTERNATE_A")
assert(task.metadata.dotted_project == nil)
vim.api.nvim_set_current_win(win_a)
task = vim.fn.maparg(" R", "n", false, true).callback()
finish(task, "PROJECT_A PROJECT_RESTART_SAVED")
assert(task.metadata.dotted_project == a)
write(a .. "/README.md", { "# Project documentation" })
vim.api.nvim_set_current_win(win_a)
vim.cmd.edit(vim.fn.fnameescape(a .. "/README.md"))
assert(vim.fn.maparg("]]", "n", false, true).buffer == 1, "Markdown navigation mapping was lost")
assert(vim.fn.maparg("]]", "x", false, true).buffer == 1, "Markdown visual navigation mapping was lost")
task = require("ui.run_toolbar").action(10)
finish(task, "PROJECT_A PROJECT_RESTART_SAVED")
assert(task.metadata.dotted_project == a)

-- A src-layout package runs as a module, so relative imports work while the
-- application's working directory remains the project root.
local module = dir .. "/module app"
write(module .. "/pyproject.toml", { "[project]", 'name="module-app"' })
write(module .. "/src/app/__main__.py", { "from .helper import VALUE", "print(VALUE, flush=True)" })
write(module .. "/src/app/helper.py", { "VALUE = 'PYTHON_PROJECT_MODULE'" })
vim.cmd.edit(vim.fn.fnameescape(module .. "/src/app/helper.py"))
task = run.project()
finish(task, "PYTHON_PROJECT_MODULE")
assert(task.cwd == module and task.cmd[#task.cmd] == "app")

-- A wrapper target wins over a direct interpreter launch and runs from root.
local make = dir .. "/make app"
local python = assert(require("util.platform").first_executable { "python3", "python" })
write(make .. "/pyproject.toml", { "[project]", 'name="wrapper"' })
write(make .. "/main.py", { "import os", "print(os.environ['RUN_CONFIGURATION'], flush=True)" })
write(make .. "/lib/helper.py", { "raise RuntimeError('Do not run a library file')" })
write(make .. "/Makefile", { "run:", "\t@RUN_CONFIGURATION=MAKE_PROJECT " .. vim.fn.shellescape(python) .. " main.py" })
vim.cmd.edit(vim.fn.fnameescape(make .. "/lib/helper.py"))
task = run.project()
finish(task, "MAKE_PROJECT")
assert(task.cwd == make and vim.deep_equal(task.cmd, { "make", "run" }))

-- Run a Go cmd/server package while editing an imported library. Unsaved
-- library edits must be included in the compiled application.
local go = dir .. "/go app"
write(go .. "/go.mod", { "module project.run/test", "go 1.23" })
write(go .. "/cmd/server/launch.go", {
  "package main",
  'import ("fmt"; "os"; "project.run/test/internal/message")',
  "func main() {",
  ' if os.Getenv("ARGUS_AUTH_APP_ACCESS_TOKEN_TTL") == "" { fmt.Println("missing required value: ARGUS_AUTH_APP_ACCESS_TOKEN_TTL"); os.Exit(1) }',
  " fmt.Println(message.Value)",
  ' fmt.Println("CONFIGURED_TTL", os.Getenv("ARGUS_AUTH_APP_ACCESS_TOKEN_TTL"))',
  "}",
})
write(
  go .. "/cmd/worker/launch.go",
  { "package main", 'import "fmt"', 'func main() { fmt.Println("CURRENT_GO_WORKER") }' }
)
write(go .. "/Makefile", {
  "run-server:",
  "\t@ARGUS_AUTH_APP_ACCESS_TOKEN_TTL=15m go run -buildvcs=false ./cmd/server",
  "run-worker:",
  "\t@go run -buildvcs=false ./cmd/worker",
  "run-server-stage:",
  "\t@exit 77",
})
vim.env.ARGUS_AUTH_APP_ACCESS_TOKEN_TTL = nil
write(go .. "/internal/message/message.go", { "package message", 'const Value = "OLD_GO"' })
vim.cmd.edit(vim.fn.fnameescape(go .. "/internal/message/message.go"))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "package message", 'const Value = "WHOLE_GO_PROJECT"' })
-- Several applications require a choice even if an entry point has focus.
vim.cmd.edit(vim.fn.fnameescape(go .. "/cmd/worker/launch.go"))
task = choose(run.project(), "Make: run-server")
finish(task, "WHOLE_GO_PROJECT")
assert(task.cwd == go and vim.deep_equal(task.cmd, { "make", "run-server" }))
local output = table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(), 0, -1, false), "\n")
assert(output:find("CONFIGURED_TTL 15m", 1, true), output)
task = require("ui.run_toolbar").action(1)
finish(task, "CURRENT_GO_WORKER")
task = require("ui.run_toolbar").action(10)
finish(task, "WHOLE_GO_PROJECT")
assert(vim.deep_equal(task.cmd, { "make", "run-server" }), "Focusing/running the worker changed the project target")

-- Project Run must not silently execute a standalone file.
write(dir .. "/standalone.py", { "print('STANDALONE_FILE', flush=True)" })
vim.cmd.edit(vim.fn.fnameescape(dir .. "/standalone.py"))
local selected, notify, warned = require("ui.output").selected, vim.notify, false
vim.notify = function(message, ...)
  if message == "No project run target found" then
    warned = true
  else
    notify(message, ...)
  end
end
assert(run.project() == nil)
vim.notify = notify
assert(warned and require("ui.output").selected == selected, "Project Run fell back to the current file")
task = run.file()
finish(task, "STANDALONE_FILE")
assert(vim.bo[unrelated].modified and vim.fn.readfile(outside)[1] == "print('UNRELATED_DISK')")
assert(vim.v.errmsg == "", vim.v.errmsg)
print "File/Project Run: separate buttons and keys, stable project targets from other entry points/docs, environment wrappers, project saves and pinned restarts passed"
