-- Detect real fixture entry points without enumerating asynchronous providers.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local run = require "util.run"
local dir = vim.fn.tempname() .. " project 100%"
vim.fn.mkdir(dir .. "/node/src", "p")
vim.fn.writefile({ [[{"scripts":{"test":"node test.js","dev":"node index.js"}}]] }, dir .. "/node/package.json")
local tasks = run.detect(dir .. "/node/src/app.js")
assert(#tasks == 2 and tasks[1].default and tasks[1].name == "npm run dev")
assert(vim.deep_equal(tasks[1].command, { "npm", "run", "dev" }) and tasks[1].cwd == dir .. "/node")
vim.fn.writefile({}, dir .. "/node/pnpm-lock.yaml")
assert(run.detect(dir .. "/node/src/app.js")[1].command[1] == "pnpm")
vim.fn.mkdir(dir .. "/go/cmd/server", "p")
vim.fn.writefile({ "module test/project" }, dir .. "/go/go.mod")
vim.fn.writefile({ "package main", "func main(){}" }, dir .. "/go/cmd/server/main.go")
tasks = run.detect(dir .. "/go/cmd/server/main.go")
assert(#tasks == 1 and vim.deep_equal(tasks[1].command, { "go", "run", "-buildvcs=false", "./cmd/server" }))
vim.fn.mkdir(dir .. "/rust/src", "p")
vim.fn.writefile({ "[package]", 'name="test"' }, dir .. "/rust/Cargo.toml")
assert(vim.deep_equal(run.detect(dir .. "/rust/src/main.rs")[1].command, { "cargo", "run" }))
vim.fn.mkdir(dir .. "/python", "p")
vim.fn.writefile({ "[project]", 'name="test"' }, dir .. "/python/pyproject.toml")
vim.fn.writefile({ "print('test')" }, dir .. "/python/__main__.py")
tasks = run.detect(dir .. "/python/__main__.py")
assert(#tasks == 1 and tasks[1].name == "Python: project")
vim.fn.mkdir(dir .. "/make", "p")
vim.fn.writefile({ "run:", "\t@echo test" }, dir .. "/make/Makefile")
assert(vim.deep_equal(run.detect(dir .. "/make/app.py")[1].command, { "make", "run" }))
assert(#run.detect(dir .. "/standalone.py") == 0)
vim.fn.writefile({ "{malformed" }, dir .. "/node/package.json")
assert(#run.detect(dir .. "/node/src/app.js") == 0)
-- A workspace's package manager also applies to nested packages. A package
-- without its own launch script should use the workspace's application task.
vim.fn.mkdir(dir .. "/workspace/packages/app/src", "p")
vim.fn.writefile({ '{"scripts":{"dev":"workspace dev"}}' }, dir .. "/workspace/package.json")
vim.fn.writefile({}, dir .. "/workspace/pnpm-lock.yaml")
vim.fn.writefile({ '{"scripts":{"dev":"app dev"}}' }, dir .. "/workspace/packages/app/package.json")
tasks = run.detect(dir .. "/workspace/packages/app/src/main.ts")
assert(tasks[1].command[1] == "pnpm" and tasks[1].cwd == dir .. "/workspace/packages/app")
vim.fn.writefile({ '{"packageManager":"bun@1.3.0","scripts":{"dev":"app dev"}}' }, dir .. "/workspace/packages/app/package.json")
assert(run.detect(dir .. "/workspace/packages/app/src/main.ts")[1].command[1] == "bun")
vim.fn.writefile({ '{"scripts":{"lint":"eslint ."}}' }, dir .. "/workspace/packages/app/package.json")
tasks = run.detect(dir .. "/workspace/packages/app/src/main.ts")
assert(tasks[1].cwd == dir .. "/workspace", "A lint-only package hid the workspace launch command")
vim.fn.mkdir(dir .. "/workspace/independent/src", "p")
vim.fn.mkdir(dir .. "/workspace/independent/.git", "p")
assert(#run.detect(dir .. "/workspace/independent/src/one.ts") == 0, "Detection escaped the repository")

-- Find a main package even if its entry file isn't called main.go. Ignore
-- library directories and nearby Makefiles which only define build targets.
vim.fn.mkdir(dir .. "/go/cmd/worker", "p")
vim.fn.writefile({ "package main", "func main(){}" }, dir .. "/go/cmd/worker/launch.go")
vim.fn.mkdir(dir .. "/go/internal/service", "p")
vim.fn.writefile({ "test:", "\t@echo test" }, dir .. "/go/internal/service/Makefile")
tasks = run.detect(dir .. "/go/internal/service/service.go")
assert(#tasks == 2 and tasks[1].cwd == dir .. "/go")
vim.fn.writefile({ ".PHONY: run dev", "run dev:", "\t@echo run" }, dir .. "/go/Makefile")
tasks = run.detect(dir .. "/go/internal/service/service.go")
assert(tasks[1].default and vim.deep_equal(tasks[1].command, { "make", "run" }), "Make's launch wrapper wasn't preferred")
-- Per-binary wrappers are also launch commands. Keep each entry associated
-- with its own target, and never substitute a stage target for a local launch.
vim.fn.writefile({ "run-server:", "\t@echo server", "run-worker:", "\t@echo worker", "run-server-stage:", "\t@exit 77" }, dir .. "/go/Makefile")
tasks = run.detect(dir .. "/go/cmd/server/main.go")
assert(#tasks == 2, "Named Make wrappers duplicated the bare Go targets")
for _, task in ipairs(tasks) do
  local binary = vim.fs.basename(task.entry)
  assert(vim.deep_equal(task.command, { "make", "run-" .. binary }))
end
vim.fn.writefile({ "run-server-stage:", "\t@exit 77" }, dir .. "/go/Makefile")
tasks = run.detect(dir .. "/go/cmd/server/main.go")
for _, task in ipairs(tasks) do assert(task.command[1] == "go", "Selected a nonlocal wrapper") end

-- Conventional Python entry points, Django and src-layout modules use the
-- detected project's environment even when the current buffer is elsewhere.
vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX = nil, nil
vim.fn.mkdir(dir .. "/python/src/app", "p")
vim.fn.writefile({ "from . import helper" }, dir .. "/python/src/app/__main__.py")
vim.fn.mkdir(dir .. "/python/.venv/bin", "p")
local python = dir .. "/python/.venv/bin/python"
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, python)
assert(vim.uv.fs_chmod(python, 448))
tasks = run.detect(dir .. "/python/src/app/helper.py")
local module
for _, task in ipairs(tasks) do if task.name == "Python: module app" then module = task end end
assert(module and vim.deep_equal(module.command, { python, "-m", "app" }))
assert(module.cwd == dir .. "/python" and module.env.PYTHONPATH:find(dir .. "/python/src", 1, true) == 1)
vim.fn.writefile({ "# Django project" }, dir .. "/python/manage.py")
tasks = run.detect(dir .. "/python/src/app/helper.py")
assert(tasks[1].default and vim.deep_equal(tasks[1].command, { python, "manage.py", "runserver" }))
print "Run targets: workspace package managers, explicit launch commands, Go main packages, Python modules/environments, Make wrappers and repository boundaries passed"
