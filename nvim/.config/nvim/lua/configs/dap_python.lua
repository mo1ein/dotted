-- Native debugpy adapter; keep its isolated runtime separate from project Python.
local M = {}

local function executable(path)
  if not path or path == "" then return nil end
  path = vim.fn.expand(path)
  if vim.fn.executable(path) == 1 then return vim.fn.exepath(path) ~= "" and vim.fn.exepath(path) or path end
end

local function environment_python(directory)
  if not directory or directory == "" then return nil end
  local suffix = vim.fn.has "win32" == 1 and "/Scripts/python.exe" or "/bin/python"
  return executable(directory .. suffix)
end

function M.adapter_python()
  local config = require("config.debug").python or {}
  if config.adapter then return executable(config.adapter) end
  return environment_python(vim.fn.stdpath "data" .. "/debugpy")
    or environment_python(vim.fn.stdpath "data" .. "/mason/packages/debugpy/venv")
end

function M.interpreter(path)
  local config = require("config.debug").python or {}
  if config.interpreter then
    local python = executable(config.interpreter)
    assert(python, "Configured Python interpreter is not executable")
    return python
  end
  for _, variable in ipairs { "VIRTUAL_ENV", "CONDA_PREFIX" } do
    local python = environment_python(vim.env[variable])
    if python then return python end
  end
  local file = path or vim.api.nvim_buf_get_name(0)
  local directory = file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()
  while directory do
    for _, name in ipairs { ".venv", "venv" } do
      local python = environment_python(directory .. "/" .. name)
      if python then return python end
    end
    local parent = vim.fs.dirname(directory)
    if parent == directory then break end
    directory = parent
  end
  local python = executable "python3" or executable "python" or M.adapter_python()
  assert(python, "No Python interpreter found")
  return python
end

function M.setup(dap)
  dap.adapters.python = function(callback)
    local python = M.adapter_python()
    if not python then
      vim.notify("debugpy is missing. Install it in " .. vim.fn.stdpath "data"
        .. "/debugpy or set python.adapter in config/debug.lua", vim.log.levels.ERROR)
      return
    end
    callback {
      type = "executable", command = python, args = { "-m", "debugpy.adapter" },
      options = { source_filetype = "python", initialize_timeout_sec = require("config.debug").timeout },
    }
  end
  -- Current VS Code launch.json files use "debugpy"; retain the common "python" alias.
  dap.adapters.debugpy = dap.adapters.python
  local function launch(name)
    return {
      type = "python", request = "launch", name = name, cwd = "${fileDirname}",
      python = function() return { M.interpreter() } end,
      console = "integratedTerminal", justMyCode = true,
    }
  end
  local file = launch "Python: current file"
  file.program = "${file}"
  local tests = launch "Python: unittest (current file)"
  tests.module, tests.args = "unittest", { "${fileBasenameNoExtension}" }
  dap.configurations.python = { file, tests }
end

return M
