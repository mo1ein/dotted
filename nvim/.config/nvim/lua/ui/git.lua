-- Open Neogit's graph on demand, rooted at the source file rather than a panel.
local M = {}
function M.open()
  local win = require("ui.buffers").source_win()
  local path = win and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) or vim.fn.getcwd()
  local root = vim.fs.root(path, ".git") or vim.fs.root(vim.fn.getcwd(), ".git")
  if not root then vim.notify("This file is not inside a Git repository", vim.log.levels.INFO); return end
  local neogit = require "neogit"
  neogit.open { cwd = root }
  -- Public action API: all refs, graph enabled, bounded first page. The graph
  -- opens read-only; mutations remain explicit Neogit actions.
  neogit.action("log", "log_all_references", { "--graph", "--max-count=150" })()
end
return M
