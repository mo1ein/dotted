-- Keep resolved debugger launches independent of the current editor/tab/cwd.
local M = {}
local last, pending
local function snapshot(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = snapshot(item) end
  return result -- discard callable config metatables which can select another file
end
function M.last() return last end
function M.begin(source, filetype)
  if pending then return false end
  pending = { source = source, filetype = filetype, cwd = vim.fn.getcwd(), generation = require("ui.run_toolbar").generation }
  local launch = pending
  vim.defer_fn(function() if pending == launch then pending = nil end end, (require("config.debug").timeout or 30) * 1000)
  return true
end
function M.failed() pending = nil end
function M.remember(session)
  if session.parent then return end -- subprocess sessions do not replace the selected root launch
  if last and last.session == session then return end
  local toolbar = require "ui.run_toolbar"
  local source = pending and pending.source
  if not source and type(session.config.program) == "string" then
    source = { path = session.config.program, buf = vim.fn.bufnr(session.config.program) }
  end
  local config = snapshot(session.config)
  local base = pending and pending.cwd or vim.fn.getcwd()
  local function absolute(path)
    if path:sub(1, 1) == "/" or path:match("^%a:[/\\]") then return vim.fs.normalize(path) end
    return vim.fs.normalize(vim.fs.joinpath(base, path))
  end
  config.cwd = absolute(config.cwd or base)
  if (config.type == "python" or config.type == "debugpy" or config.type == "go") and type(config.program) == "string" then
    local path = config.program
    if path:sub(1, 1) ~= "/" and not path:match("^%a:[/\\]") then path = vim.fs.joinpath(config.cwd, path) end
    config.program = vim.fs.normalize(path)
  end
  last = { config = config, filetype = session.filetype, source = source, session = session }
  -- An explicit normal Run made while an adapter starts remains selected.
  if not pending or pending.generation == toolbar.generation then toolbar.mode = "debug" end
  pending = nil
end
function M.restart(record, session)
  local dap = require "dap"
  if pending then vim.notify("Debugger is starting", vim.log.levels.INFO); return end
  record = record or last
  if record then
    session = record.session
    if session and session.closed then session = nil end
  else
    session = session or dap.session()
    while session and session.parent do session = session.parent end
    if session and not session.closed then
      record = { config = snapshot(session.config), filetype = session.filetype, session = session }
    end
  end
  if not record then
    vim.notify(pending and "Debugger is starting" or "No previous debug launch", vim.log.levels.INFO)
    return
  end
  require("util.launch_save").save(record.source)
  local config = snapshot(record.config)
  require("ui.run_toolbar").select "debug"
  if session and not session.closed then
    dap.set_session(session)
    dap.restart(config, { filetype = record.filetype })
  else
    config.__restart = nil
    if not M.begin(record.source, record.filetype) then return end
    dap.run(config, { filetype = record.filetype, new = true })
  end
end
return M
