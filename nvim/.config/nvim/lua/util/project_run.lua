-- Inspect nearby manifests and entry points without spawning build tools.
local M = {}
local uv = vim.uv
local function exists(path)
  return vim.fn.filereadable(path) == 1
end
local function read(path, limit)
  if not exists(path) then
    return ""
  end
  local ok, lines
  if limit then
    ok, lines = pcall(vim.fn.readfile, path, "", limit)
  else
    ok, lines = pcall(vim.fn.readfile, path)
  end
  return ok and table.concat(lines, "\n") or ""
end
local function children(path)
  local handle = uv.fs_scandir(path)
  return function()
    if handle then
      return uv.fs_scandir_next(handle)
    end
  end
end
local function package_json(root)
  local ok, package = pcall(vim.json.decode, read(root .. "/package.json"))
  return ok and type(package) == "table" and package or {}
end
local managers = { npm = true, pnpm = true, yarn = true, bun = true }
local function package_manager(root)
  local directory = root
  while directory do
    local declared = package_json(directory).packageManager
    local name = type(declared) == "string" and declared:match "^([%w_-]+)@"
    if managers[name] then
      return name
    end
    for _, lock in ipairs {
      { "pnpm-lock.yaml", "pnpm" },
      { "yarn.lock", "yarn" },
      { "bun.lock", "bun" },
      { "bun.lockb", "bun" },
      { "package-lock.json", "npm" },
    } do
      if exists(directory .. "/" .. lock[1]) then
        return lock[2]
      end
    end
    if uv.fs_stat(directory .. "/.git") then
      break
    end
    local parent = vim.fs.dirname(directory)
    if parent == directory then
      break
    end
    directory = parent
  end
  return "npm"
end
local function go_main(directory)
  for name, kind in children(directory) do
    if kind == "file" and name:match "%.go$" and not name:match "_test%.go$" then
      local text = read(directory .. "/" .. name, 100) .. "\n"
      if text:match "^%s*package%s+main[%s;]" or text:match "\n%s*package%s+main[%s;]" then
        return true
      end
    end
  end
  return false
end
local function at_root(root)
  local tasks = {}
  local function add(name, command, opts)
    local task = vim.tbl_extend(
      "force",
      { name = name, command = command, cwd = root, root = root, runnable = true, priority = 0 },
      opts or {}
    )
    tasks[#tasks + 1] = task
  end
  if exists(root .. "/package.json") then
    local package, manager = package_json(root), package_manager(root)
    local priority = { dev = 80, start = 75, serve = 70, run = 65 }
    for name, script in pairs(type(package.scripts) == "table" and package.scripts or {}) do
      if type(name) == "string" and type(script) == "string" and script:match "%S" then
        add(
          manager .. " run " .. name,
          { manager, "run", name },
          { priority = priority[name] or 0, runnable = priority[name] ~= nil }
        )
      end
    end
  end
  if exists(root .. "/go.mod") then
    if go_main(root) then
      add("Go: project", { "go", "run", "-buildvcs=false", "." }, { entry = root })
    end
    for name, kind in children(root .. "/cmd") do
      local directory = root .. "/cmd/" .. name
      if kind == "directory" and go_main(directory) then
        local entry = "./cmd/" .. name
        add("Go: " .. entry, { "go", "run", "-buildvcs=false", entry }, { entry = directory })
      end
    end
  end
  if exists(root .. "/Cargo.toml") then
    add("Cargo: run", { "cargo", "run" })
  end
  local python_project = false
  for _, marker in ipairs {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "uv.lock",
    "uv.toml",
    "manage.py",
  } do
    if exists(root .. "/" .. marker) then
      python_project = true
      break
    end
  end
  if python_project then
    local python
    local suffix = require("util.platform").is_windows and "/Scripts/python.exe" or "/bin/python"
    local config = require("config.debug").python or {}
    local bootstrap = (exists(root .. "/uv.lock") or exists(root .. "/uv.toml"))
      and vim.fn.executable "uv" == 1
      and vim.fn.executable(root .. "/.venv" .. suffix) == 0
      and vim.fn.executable(root .. "/venv" .. suffix) == 0
      and not vim.env.VIRTUAL_ENV
      and not vim.env.CONDA_PREFIX
      and not config.interpreter
    local function command(args)
      if bootstrap then
        return vim.list_extend({ "uv", "run", "--", "python" }, args)
      end
      python = python or require("configs.dap_python").interpreter(root .. "/main.py")
      return vim.list_extend({ python }, args)
    end
    if exists(root .. "/manage.py") then
      add("Python: Django server", command { "manage.py", "runserver" }, { priority = 60 })
    else
      for _, name in ipairs { "__main__.py", "main.py", "app.py", "run.py" } do
        if exists(root .. "/" .. name) then
          add(
            name == "__main__.py" and "Python: project" or "Python: " .. name,
            command { root .. "/" .. name },
            { entry_file = root .. "/" .. name }
          )
        end
      end
      for _, prefix in ipairs { "", "src/" } do
        for name, kind in children(root .. "/" .. prefix) do
          local directory = root .. "/" .. prefix .. name
          if kind == "directory" and name:match "^[%a_][%w_]*$" and exists(directory .. "/__main__.py") then
            local env
            if prefix ~= "" then
              local separator = require("util.platform").is_windows and ";" or ":"
              env = { PYTHONPATH = root .. "/src" .. (vim.env.PYTHONPATH and (separator .. vim.env.PYTHONPATH) or "") }
            end
            add("Python: module " .. name, command { "-m", name }, { entry = directory, env = env })
          end
        end
      end
    end
  end
  for _, makefile in ipairs { "GNUmakefile", "makefile", "Makefile" } do
    if exists(root .. "/" .. makefile) then
      local targets = {}
      for line in (read(root .. "/" .. makefile) .. "\n"):gmatch "([^\n]*)\n" do
        if line:sub(1, 1) ~= "\t" then
          local names, after = line:match "^%s*([^:#=]+)%s*:(.*)$"
          if names and not after:match "^=" then
            for name in names:gmatch "%S+" do
              targets[name] = true
            end
          end
        end
      end
      -- Named launch wrappers supply environment/setup that bare go run lacks.
      for _, task in ipairs(tasks) do
        if task.entry and task.command[1] == "go" then
          for _, action in ipairs { "run", "dev", "start" } do
            local target = action .. "-" .. vim.fs.basename(task.entry)
            if targets[target] then
              task.name, task.command = "Make: " .. target, { "make", target }
              break
            end
          end
        end
      end
      for i, target in ipairs { "run", "dev", "start" } do
        if targets[target] then
          add("Make: " .. target, { "make", target }, { priority = 110 - i * 5 })
        end
      end
      break
    end
  end
  table.sort(tasks, function(a, b)
    return a.priority > b.priority or (a.priority == b.priority and a.name < b.name)
  end)
  if tasks[1] and tasks[1].priority > 0 then
    tasks[1].default = true
  end
  for _, task in ipairs(tasks) do
    task.priority = nil
  end
  return tasks
end
function M.detect(path)
  path = path and path ~= "" and path or vim.fn.getcwd()
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  local stat = uv.fs_stat(path)
  local directory = stat and stat.type == "directory" and path or vim.fs.dirname(path)
  local fallback, fallback_root
  while directory do
    local tasks = at_root(directory)
    if #tasks > 0 then
      for _, task in ipairs(tasks) do
        if task.runnable then
          return tasks, directory
        end
      end
      if not fallback then
        fallback, fallback_root = tasks, directory
      end
    end
    if uv.fs_stat(directory .. "/.git") then
      break
    end
    local parent = vim.fs.dirname(directory)
    if parent == directory then
      break
    end
    directory = parent
  end
  return fallback or {}, fallback_root
end
return M
