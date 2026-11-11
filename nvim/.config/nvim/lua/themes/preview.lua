-- Picker-scoped, debounced live preview. Closing stops and closes the timer.
local M = {}

function M.new(loader, remember, delay)
  local original, background = loader.current(), vim.o.background
  local timer = assert(vim.uv.new_timer())
  local finished, stopped, pending, generation = false, false, false, 0
  local session = {}

  function session.stop()
    stopped = true
    generation = generation + 1
    if not timer:is_closing() then timer:stop(); timer:close() end
  end

  function session.hover(name)
    if stopped or finished or not name or name == "" then return end
    generation = generation + 1
    local request = generation
    timer:stop()
    if name == loader.current() then return end
    timer:start(delay or 120, 0, vim.schedule_wrap(function()
      if not stopped and not finished and request == generation then loader.apply(name) end
    end))
  end

  function session.finish(name)
    if finished then return end
    finished = true
    session.stop()
    if name then
      if remember or name ~= loader.current() then
        if loader.apply(name, remember) == false and original then loader.apply(original, false, background) end
      end
    elseif original and (original ~= loader.current() or background ~= vim.o.background) then
      loader.apply(original, false, background)
    end
  end

  function session.cancel_if_idle()
    if not pending then session.finish() end
  end

  function session.choose(name, confirm)
    if finished or pending then return end
    if not name then session.finish(); return end
    pending = true
    session.stop()
    -- Enter may arrive before the debounced hover; preview the selected row now.
    if name ~= loader.current() and loader.apply(name) == false then
      pending = false
      session.finish()
      return
    end
    local ok, err = pcall(confirm, name, function(accepted)
      pending = false
      session.finish(accepted and name or nil)
    end)
    if not ok then pending = false; session.finish(); vim.notify(tostring(err), vim.log.levels.ERROR) end
  end

  return session
end

return M
