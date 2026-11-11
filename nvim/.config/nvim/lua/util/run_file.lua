-- Execute the focused source using argv, without an intermediate login shell.
local platform = require "util.platform"
local function executable(candidates)
  local bin = platform.first_executable(candidates)
  if not bin then vim.notify("run: none of " .. table.concat(candidates, ", ") .. " found in PATH", vim.log.levels.ERROR) end
  return bin
end
local function output(command, opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.fn.expand "%:p:h"
  return require("ui.output").run(command, opts)
end
local function run(candidates, arguments, opts)
  local bin = executable(candidates)
  if bin then return output(vim.list_extend({ bin }, arguments), opts) end
end
local function try_command(name, missing)
  if vim.fn.exists(":" .. name) ~= 0 then vim.cmd(name)
  elseif missing then missing() else vim.notify("run: " .. name .. " is unavailable", vim.log.levels.ERROR) end
end
local runners = {
  markdown = function() try_command "MarkdownPreview" end,
  tex = function(file)
    try_command("VimtexCompile", function() return run({ "latexmk" }, { "-pdf", "-interaction=nonstopmode", file }) end)
  end,
  go = function(file)
    -- Editor runs don't need build-info VCS stamping. Avoid making Go walk
    -- large repositories to collect it on every Run click.
    if vim.fs.root(file, "go.mod") then
      return run({ "go" }, { "run", "-buildvcs=false", "." }, { name = "Go: current package" })
    end
    return run({ "go" }, { "run", "-buildvcs=false", file })
  end,
  python = function(file)
    local root = vim.fs.root(file, { "uv.lock", "uv.toml" })
    local suffix = vim.fn.has "win32" == 1 and "/Scripts/python.exe" or "/bin/python"
    local has_env = root and vim.fn.executable(root .. "/.venv" .. suffix) == 1
    -- Bootstrap a uv environment only when needed. Once it exists, run its
    -- interpreter directly instead of resolving/syncing the project every time.
    if root and not has_env and not vim.env.VIRTUAL_ENV and not vim.env.CONDA_PREFIX
      and not (require("config.debug").python or {}).interpreter then
      return run({ "uv" }, { "run", "--", file }, { cwd = root })
    end
    return output({ require("configs.dap_python").interpreter(), file })
  end,
  javascript = function(file) return run({ "node" }, { file }) end,
  lua = function(file)
    local bin = platform.first_executable { "lua", "luajit" }
    if bin then return output { bin, file } end
    return output { vim.v.progpath, "--headless", "-u", "NONE", "-l", file }
  end,
  sh = function(file) return run({ "bash", "sh" }, { file }) end,
  zsh = function(file) return run({ "zsh" }, { file }) end,
  rust = function(file)
    local root = vim.fs.root(file, "Cargo.toml")
    if not root then vim.notify("run: Cargo project not found", vim.log.levels.WARN); return end
    return run({ "cargo" }, { "run" }, { cwd = root })
  end,
}
local function compile(candidates, file)
  local bin = executable(candidates)
  if not bin then return end
  local target = vim.fn.fnamemodify(file, ":r")
  return output(("%s %s -o %s && %s"):format(vim.fn.shellescape(bin), vim.fn.shellescape(file), vim.fn.shellescape(target), vim.fn.shellescape(target)))
end
runners.c = function(file) return compile({ "cc", "gcc", "clang" }, file) end
runners.cpp = function(file) return compile({ "c++", "g++", "clang++" }, file) end
runners.bash, runners.typescript = runners.sh, runners.javascript
return function()
  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then vim.notify("run: buffer has no file name", vim.log.levels.WARN); return end
  local runner = runners[vim.bo.filetype]
  if not runner then vim.notify("run: no runner for " .. vim.bo.filetype, vim.log.levels.WARN); return end
  require("util.launch_save").save { buf = vim.api.nvim_get_current_buf(), path = file }
  return runner(file)
end
