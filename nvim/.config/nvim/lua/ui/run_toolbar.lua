-- Compact run/debug controls matching the rest of the native mouse UI.
local M = { mode = "run", generation = 0 }
function M.select(mode) M.mode = mode; M.generation = M.generation + 1 end
function M.context()
  local output, d = package.loaded["ui.output"], package.loaded.dap
  return { mode = M.mode, task = output and output.selected,
    session = d and d.session and d.session(), debug = require("util.debug_session").last() }
end
local function dap()
  local d = package.loaded.dap
  return M.mode == "debug" and d and d.session and d.session() and d or nil
end
function M.render()
  local d, output = dap(), package.loaded["ui.output"]
  local task = M.mode == "run" and output and output.selected
  local running = task and task:is_running()
  local paused = d and d.session().stopped_thread_id or (M.mode == "run" and output and output.paused)
  local out = {}
  local icons = { "▶ File", "▾", paused and "▶" or "⏸", "󰆷", "󰆹", "󰆸", "↻", "□", "󰃤", "▶ Project" }
  for _, id in ipairs { 1, 10, 2, 9, 3, 4, 5, 6, 7, 8 } do
    local icon = icons[id]
    out[#out + 1] = require("ui.controls").button("run", id, icon, "DottedRunControlClick", (id == 3 and paused) or (id == 9 and M.mode == "debug"),
      (id == 1 or id == 10 or id == 7) and "DiagnosticOk" or id == 8 and "DiagnosticError" or id == 3 and "DiagnosticInfo" or (id >= 4 and id <= 6 and not d) and "Comment" or nil)
  end
  return table.concat(out)
end
function M.action(id, target, context)
  context = context or M.context()
  local d = dap()
  if id == 1 then M.select "run"; return require("util.run").file(target)
  elseif id == 10 then M.select "run"; return require("util.run").project(target)
  elseif id == 2 then return require("util.run").pick(target)
  elseif id == 9 then
    M.select "debug"
    if not require("util.run").debug(target) then M.select "run" end
  elseif id == 3 then
    if context.mode == "debug" then
      if d then if d.session().stopped_thread_id then d.continue() else d.pause() end end
    else require("ui.output").pause() end
  elseif id >= 4 and id <= 6 then
    if d then d[({ [4] = "step_over", [5] = "step_into", [6] = "step_out" })[id]]()
    else vim.notify("Start a debug session to step through code", vim.log.levels.INFO) end
  elseif id == 7 then
    if context.mode == "debug" then require("util.debug_session").restart(context.debug, context.session)
    elseif context.task then require("ui.output").restart(context.task) end
  elseif id == 8 then
    if context.mode == "debug" then if d then d.terminate() end
    else require("ui.output").stop() end
  end
  vim.cmd.redrawtabline()
end
function M.setup()
  _G.DottedRunControlClick = function(id)
    local target, context = require("util.run").capture(), M.context()
    vim.schedule(function() M.action(id, target, context) end)
  end
end
return M
