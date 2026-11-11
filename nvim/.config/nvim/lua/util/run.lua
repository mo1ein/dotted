-- Resolve explicit project entry points without waiting for a task-provider scan.
local M = {}
local choices = {}
function M.capture()
  local replace = package.loaded["ui.replace"]
  local widget = replace and replace.current()
  local win = widget and widget.origin or require("ui.buffers").source_win()
  if win then return { win = win, buf = vim.api.nvim_win_get_buf(win), tab = vim.api.nvim_get_current_tabpage() } end
end
local function source(target)
  target = target or M.capture()
  if not target or vim.api.nvim_get_current_tabpage() ~= target.tab
    or not vim.api.nvim_win_is_valid(target.win) or vim.api.nvim_win_get_buf(target.win) ~= target.buf then return nil end
  vim.api.nvim_set_current_win(target.win)
  return target.win
end
function M.file(target)
  if not source(target) then return vim.notify("Open a source file first", vim.log.levels.WARN) end
  if package.loaded["ui.run_toolbar"] then require("ui.run_toolbar").select "run" end
  return require "util.run_file"()
end
function M.debug(target)
  local win = source(target)
  if not win then return false end
  local buf = vim.api.nvim_win_get_buf(win)
  local filetype = vim.bo[buf].filetype
  local path = vim.api.nvim_buf_get_name(buf)
  local source_file = path ~= "" and { buf = buf, path = path } or nil
  local dap = require "dap"
  local session = dap.session()
  if session then
    require("ui.dap").open()
    if not session.initialized then
      vim.notify("Debugger is starting", vim.log.levels.INFO)
    elseif session.stopped_thread_id then
      dap.continue()
    else
      vim.notify("Debug session is already running", vim.log.levels.INFO)
    end
    return true
  end
  local configs = dap.configurations[filetype] or {}
  local selected
  for _, config in ipairs(configs) do
    if config.request == "launch" and ((filetype == "go" and config.name == "Go: current package")
      or (filetype ~= "go" and config.program == "${file}")) then selected = config; break end
  end
  selected = selected or configs[1]
  if not selected then
    vim.notify("No debugger configured for " .. filetype, vim.log.levels.WARN)
    return false
  end
  local save = require "util.launch_save"
  if not require("util.debug_session").begin(source_file, filetype) then return true end
  save.save(source_file)
  local ok, err = pcall(dap.run, vim.deepcopy(selected))
  if not ok then require("util.debug_session").failed(); error(err) end
  require("ui.dap").open()
  return true
end
function M.detect(path)
  return require("util.project_run").detect(path or vim.api.nvim_buf_get_name(0))
end
function M.start(task, target)
  if not source(target) then return end
  if package.loaded["ui.run_toolbar"] then require("ui.run_toolbar").select "run" end
  local root = vim.fs.normalize(vim.fn.fnamemodify(task.root or task.cwd or vim.fn.getcwd(), ":p"))
  if #root > 1 and not root:match "^%a:/$" then root = root:gsub("/$", "") end
  choices[root] = { command = vim.deepcopy(task.command), cwd = task.cwd, env = vim.deepcopy(task.env) }
  require("util.launch_save").project(root)
  return require("ui.output").run(task.command, { cwd = task.cwd, name = task.name, env = task.env, project_root = root })
end
function M.pick(target, tasks)
  target = target or M.capture()
  if not source(target) then return end
  tasks = tasks or M.detect()
  if #tasks == 0 then return vim.notify("No project run target found", vim.log.levels.WARN) end
  local items = {}
  for _, task in ipairs(tasks) do
    items[#items + 1] = { label = "▶ " .. task.name, action = function(menu) menu:close(); M.start(task, target) end }
  end
  return require("ui.menu").open { title = "Project run target", items = items }
end
function M.project(target)
  target = target or M.capture()
  if not source(target) then return vim.notify("Open a source file first", vim.log.levels.WARN) end
  local path = vim.api.nvim_buf_get_name(target.buf)
  local tasks, root = M.detect(path)
  local choice = root and choices[root]
  for _, task in ipairs(tasks) do
    if choice and vim.deep_equal(choice, { command = task.command, cwd = task.cwd, env = task.env }) then
      return M.start(task, target)
    end
  end
  if tasks[1] and tasks[1].default then return M.start(tasks[1], target) end
  if #tasks == 1 and tasks[1].runnable ~= false then return M.start(tasks[1], target) end
  return M.pick(target, tasks)
end
return M
