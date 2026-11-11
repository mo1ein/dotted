-- Persistent Overseer task output, displayed by the owned tool drawer.
local M = { selected = nil }
local restarting = {}
function M.tasks() return require("overseer").list_tasks {} end
local function show_when_ready(task)
  if not require("config.ui").tools.enabled then
    task:open_output()
    return
  end
  local tab, deadline = vim.api.nvim_get_current_tabpage(), vim.uv.hrtime() + 10000000000
  require("ui.tools").show("Output")
  local function attach()
    if M.selected ~= task or vim.api.nvim_get_current_tabpage() ~= tab then return end
    local tools = require("ui.tools").current()
    if tools.selected ~= "Output" then return end
    local buf = task:get_bufnr()
    if buf and vim.api.nvim_buf_is_valid(buf) then
      if tools.buf ~= buf then require("ui.tools").show("Output") end
    elseif vim.uv.hrtime() < deadline then
      vim.defer_fn(attach, 20)
    end
  end
  vim.defer_fn(attach, 20)
end
function M.buffer()
  if M.selected and M.selected:get_bufnr() then return M.selected:get_bufnr() end
  for _, task in ipairs(M.tasks()) do
    if task:get_bufnr() then M.selected = task; return task:get_bufnr() end
  end
end
local function absolute_directory(path)
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  return #path > 1 and not path:match("^%a:/$") and path:gsub("/$", "") or path
end
function M.run(command, opts)
  opts = opts or {}
  if M.paused then M.pause() end
  M.paused, M.paused_pid = false, nil
  local source = opts.source or require("util.launch_save").capture()
  if package.loaded["ui.run_toolbar"] then require("ui.run_toolbar").select "run" end
  local task = require("overseer").new_task {
    name = opts.name or (type(command) == "string" and command or table.concat(command, " ")),
    cmd = vim.deepcopy(command), cwd = absolute_directory(opts.cwd or vim.fn.getcwd()), env = vim.deepcopy(opts.env),
    metadata = { dotted_source = source, dotted_project = opts.project_root },
    -- No automatic disposal: hiding Output must not lose the process/scrollback.
    components = { "on_exit_set_status" },
  }
  M.selected = task
  task:start()
  show_when_ready(task)
  return task
end
function M.pick()
  local items = {}
  for _, task in ipairs(M.tasks()) do
    if task:get_bufnr() then
      items[#items + 1] = { label = task.status .. "  " .. task.name, action = function(menu)
        menu:close(); if M.paused then M.resume() end; M.selected = task; require("ui.run_toolbar").select "run"; require("ui.tools").show("Output")
      end }
    end
  end
  return require("ui.menu").open { title = "Task output", items = items }
end
function M.resume()
  if M.paused_pid then vim.uv.kill(M.paused_pid, "sigcont") end
  M.paused, M.paused_pid = false, nil
  vim.cmd.redrawtabline()
end
function M.pause()
  if M.paused then return M.resume() end
  local task = M.selected
  if not task or not task:is_running() then return end
  if vim.fn.has "win32" == 1 then vim.notify("Process pause needs a debugger on Windows", vim.log.levels.INFO); return end
  -- Overseer's jobstart strategy owns the process; its terminal buffer uses a
  -- separate display channel, so terminal_job_id is not the process job ID.
  local job = task.strategy and task.strategy.job_id
  if not job then return end
  local pid = vim.fn.jobpid(job)
  local target = M.paused_pid or -pid
  local ok = vim.uv.kill(target, M.paused and "sigcont" or "sigstop")
  if not ok and not M.paused then target = pid; ok = vim.uv.kill(target, "sigstop") end
  if ok then M.paused = not M.paused; M.paused_pid = M.paused and target or nil end
  vim.cmd.redrawtabline()
end
function M.stop()
  if M.selected then restarting[M.selected.id] = nil end
  if M.paused then M.pause() end
  if M.selected and M.selected:is_running() then M.selected:stop() end
end
function M.restart(task)
  task = task or M.selected
  if not task then return end
  local metadata = task.metadata or {}
  if metadata.dotted_project then require("util.launch_save").project(metadata.dotted_project)
  else require("util.launch_save").save(metadata.dotted_source) end
  M.selected = task
  require("ui.run_toolbar").select "run"
  if M.paused then M.pause() end
  if restarting[task.id] then return end
  local token, tab = {}, vim.api.nvim_get_current_tabpage()
  restarting[task.id] = token
  local job = task.strategy and task.strategy.job_id
  local function start()
    if restarting[task.id] ~= token then return end
    restarting[task.id] = nil
    local tools = package.loaded["ui.tools"]
    local visible = M.selected == task and vim.api.nvim_get_current_tabpage() == tab
      and require("ui.run_toolbar").mode == "run"
    -- Detach only the output buffer before Overseer disposes/replaces it.
    local showing = visible and tools and tools.prepare_output_restart()
    task:restart()
    if showing then tools.show("Output") end
  end
  if not task:is_running() then start(); return end
  local ok, pid = false, nil
  if job then ok, pid = pcall(vim.fn.jobpid, job) end
  local process = ok and pid and (vim.uv.kill(-pid, 0) and -pid or pid) or nil
  task:stop()
  if not process then vim.schedule(start); return end
  local deadline = vim.uv.hrtime() + 5000000000
  local function stopped()
    if restarting[task.id] ~= token then return end
    -- jobwait(0) can still drain callbacks synchronously after jobstop.
    -- Probe the original process group instead; no editor/event-loop wait.
    if not vim.uv.kill(process, 0) then start()
    elseif vim.uv.hrtime() < deadline then vim.defer_fn(stopped, 10)
    else
      restarting[task.id] = nil
      vim.notify("Previous process is still stopping; rerun once it exits", vim.log.levels.WARN)
    end
  end
  stopped()
end
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("DottedRunProcess", { clear = true }),
  callback = M.resume,
})
return M
