-- Terminal mappings do not expose modifier-only release events. On a local
-- Mac, read only the modifier flags (no event tap, key capture or permissions).
local M = {}
local checked, core
function M.is_down(modifier)
  if vim.fn.has("macunix") ~= 1 or vim.env.SSH_CONNECTION or vim.env.SSH_TTY then return nil end
  if not checked then
    checked = true
    local ffi = require "ffi"
    pcall(ffi.cdef, "unsigned long long CGEventSourceFlagsState(int stateID);")
    local ok, library = pcall(ffi.load, "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    if ok then core = library end
  end
  if not core then return nil end
  local ok, flags = pcall(function() return tonumber(core.CGEventSourceFlagsState(0)) end)
  if not ok then return nil end
  local mask = modifier == "alt" and 0x80000 or 0x40000
  return require("bit").band(flags, mask) ~= 0
end

function M.watch(modifier, released)
  if M.is_down(modifier) == nil then return nil end
  local timer, stopped = assert(vim.uv.new_timer()), false
  local function stop()
    if stopped then return end
    stopped = true
    timer:stop()
    timer:close()
  end
  -- This samples state, not inactivity: holding the modifier never expires.
  timer:start(0, 8, vim.schedule_wrap(function()
    if stopped then return end
    if M.is_down(modifier) ~= true then stop(); released() end
  end))
  return stop
end
return M
