-- Save launch inputs without waiting for format-on-save.
local M = {}
function M.capture()
  local win = require("ui.buffers").source_win()
  if not win then return nil end
  local buf = vim.api.nvim_win_get_buf(win)
  local path = vim.api.nvim_buf_get_name(buf)
  return path ~= "" and { buf = buf, path = path } or nil
end
function M.save(source)
  if not source then return end
  local buf = source.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_name(buf) ~= source.path then
    buf = vim.fn.bufnr(source.path)
  end
  if buf < 0 or not vim.api.nvim_buf_is_loaded(buf) or not vim.bo[buf].modified then return end
  local previous = vim.b[buf].dotted_launch_save
  vim.b[buf].dotted_launch_save = true
  local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd "silent update" end)
  vim.b[buf].dotted_launch_save = previous
  if not ok then error(err) end
end
function M.project(root)
  local prefix = vim.fs.normalize(vim.fn.fnamemodify(root, ":p")):gsub("/$", "") .. "/"
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" and vim.bo[buf].modified then
      local path = vim.api.nvim_buf_get_name(buf)
      if path:sub(1, #prefix) == prefix then M.save { buf = buf, path = path } end
    end
  end
end
return M
