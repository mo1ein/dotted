-- Single source of truth for "which OS am I on".
-- Every OS-conditional branch in this config goes through here so there is
-- exactly one place to fix when a new platform shows up.

local M = {}

--- @return "macos"|"linux"|"windows"
function M.name()
  if vim.fn.has "mac" == 1 then
    return "macos"
  elseif vim.fn.has "win32" == 1 or vim.fn.has "win64" == 1 then
    return "windows"
  end
  return "linux"
end

M.is_mac = M.name() == "macos"
M.is_linux = M.name() == "linux"
M.is_windows = M.name() == "windows"

--- First executable found in the list, or nil.
--- @param candidates string[]
--- @return string|nil
function M.first_executable(candidates)
  for _, bin in ipairs(candidates) do
    if vim.fn.executable(bin) == 1 then
      return bin
    end
  end
  return nil
end

--- The platform's "open this with the default app" command.
--- @return string
function M.opener()
  if M.is_mac then
    return "open"
  elseif M.is_windows then
    return "start"
  end
  return "xdg-open"
end

return M
