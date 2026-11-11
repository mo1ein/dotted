-- Saved theme lives inside the owned config, without overwriting custom settings.
-- The generated Lua file contains a single literal, never executable theme data.
local M = {}

function M.path()
  return vim.fn.stdpath "config" .. "/lua/config/theme_choice.lua"
end

function M.legacy_path()
  return vim.fn.stdpath "state" .. "/theme"
end

function M.read()
  if vim.fn.filereadable(M.path()) == 0 then return nil end
  local source = table.concat(vim.fn.readfile(M.path()), "\n")
  source = source:gsub("^%s*%-%-[^\n]*\n", "")
  local _, name = source:match("^%s*return%s+(['\"])([%w_-]+)%1%s*$")
  if not name then return nil, "Invalid saved theme in " .. M.path() end
  return name
end

function M.save(name)
  if not name:match "^[%w_-]+$" then return nil, "Invalid theme name" end
  local path = M.path()
  local link = vim.uv.fs_lstat(path)
  if link and link.type == "link" and not vim.uv.fs_realpath(path) then return nil, "Saved-theme symlink is broken" end
  path = vim.uv.fs_realpath(path) or path
  local stat = vim.uv.fs_stat(path)
  if stat and not vim.uv.fs_access(path, "W") then return nil, "Saved-theme config is read-only: " .. path end
  local directory = vim.fn.fnamemodify(path, ":h")
  local ok, err = pcall(vim.fn.mkdir, directory, "p")
  if not ok then return nil, err end
  local temporary = path .. ".tmp-" .. vim.uv.os_getpid() .. "-" .. tostring(vim.uv.hrtime())
  local contents = '-- Saved after theme confirmation. :ThemeReset removes this override.\nreturn ' .. string.format("%q", name) .. "\n"
  local fd
  fd, err = vim.uv.fs_open(temporary, "wx", stat and stat.mode % 512 or 420)
  if not fd then return nil, err end
  local bytes, write_error = vim.uv.fs_write(fd, contents, 0)
  local closed, close_error = vim.uv.fs_close(fd)
  if bytes ~= #contents or not closed then
    vim.uv.fs_unlink(temporary)
    return nil, write_error or close_error or "Incomplete saved-theme write"
  end
  ok, err = vim.uv.fs_rename(temporary, path)
  if not ok then vim.uv.fs_unlink(temporary); return nil, err end
  -- Config now wins over the old per-machine state-file preference.
  if vim.fn.filereadable(M.legacy_path()) == 1 then vim.fn.delete(M.legacy_path()) end
  return true
end

function M.reset()
  for _, path in ipairs { M.path(), M.legacy_path() } do
    if vim.uv.fs_lstat(path) then
      local ok, err = vim.uv.fs_unlink(path)
      if not ok then return nil, err end
    end
  end
  return true
end

return M
