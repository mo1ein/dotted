-- Run the current file according to its filetype.
--
-- Every runner resolves its interpreter/compiler through platform.first_executable
-- so the same mapping works on Linux and macOS instead of assuming a binary that
-- only one of them ships (e.g. `lua` exists on Debian, not on a stock mac).

local platform = require "util.platform"

--- Run a shell command through :! , or report which tool is missing.
--- @param candidates string[] executables to try, in order of preference
--- @param build fun(bin: string): string builds the shell command from the winner
local function run_with(candidates, build)
  local bin = platform.first_executable(candidates)
  if not bin then
    vim.notify(
      ("run: none of %s found in PATH"):format(table.concat(candidates, ", ")),
      vim.log.levels.ERROR
    )
    return
  end
  vim.cmd("!" .. build(bin))
end

--- True when the cwd looks like a uv-managed Python project.
local function is_uv_project()
  local cwd = vim.fn.getcwd()
  for _, marker in ipairs { "/uv.lock", "/uv.toml", "/pyproject.toml" } do
    if vim.fn.filereadable(cwd .. marker) == 1 then
      return true
    end
  end
  return false
end

--- Run a user command if the plugin providing it is loaded, else fall back.
local function try_cmd(name, fallback)
  if vim.fn.exists(":" .. name) ~= 0 then
    vim.cmd(name)
    return true
  end
  if fallback then
    fallback()
  end
  return false
end

local runners = {
  markdown = function()
    try_cmd("MarkdownPreview", function()
      vim.notify("run: markdown-preview.nvim is not installed", vim.log.levels.ERROR)
    end)
  end,

  go = function()
    try_cmd("GoRun", function()
      run_with({ "go" }, function(bin)
        return bin .. " run %"
      end)
    end)
  end,

  python = function()
    if is_uv_project() then
      run_with({ "uv" }, function(bin)
        return bin .. " run %"
      end)
    else
      -- macOS has no bare `python`; Debian needs python-is-python3 for it
      run_with({ "python3", "python" }, function(bin)
        return bin .. " %"
      end)
    end
  end,

  tex = function()
    try_cmd("VimtexCompile", function()
      run_with({ "latexmk" }, function(bin)
        return bin .. " -pdf -interaction=nonstopmode %"
      end)
    end)
  end,

  lua = function()
    -- A stock macOS has neither; nvim itself can always run a Lua file
    local bin = platform.first_executable { "lua", "luajit" }
    if bin then
      vim.cmd("!" .. bin .. " %")
    else
      vim.cmd "luafile %"
    end
  end,

  sh = function()
    run_with({ "bash", "sh" }, function(bin)
      return bin .. " %"
    end)
  end,

  javascript = function()
    run_with({ "node" }, function(bin)
      return bin .. " %"
    end)
  end,

  rust = function()
    run_with({ "cargo" }, function(bin)
      return bin .. " run"
    end)
  end,

  c = function()
    local out = vim.fn.expand "%:r"
    -- `cc` is clang on macOS and gcc on Debian — present on both
    run_with({ "cc", "gcc", "clang" }, function(bin)
      return ("%s %s -o %s && ./%s"):format(bin, vim.fn.expand "%", out, out)
    end)
  end,

  cpp = function()
    local out = vim.fn.expand "%:r"
    run_with({ "c++", "g++", "clang++" }, function(bin)
      return ("%s %s -o %s && ./%s"):format(bin, vim.fn.expand "%", out, out)
    end)
  end,
}

-- filetypes that share a runner
runners.bash = runners.sh
runners.zsh = runners.sh
runners.typescript = runners.javascript

return function()
  if vim.fn.expand "%" == "" then
    vim.notify("run: buffer has no file name", vim.log.levels.WARN)
    return
  end

  local ft = vim.bo.filetype
  local runner = runners[ft]
  if not runner then
    vim.notify("run: no runner defined for filetype " .. (ft == "" and "?" or ft), vim.log.levels.WARN)
    return
  end

  vim.cmd "write"
  runner()
end
