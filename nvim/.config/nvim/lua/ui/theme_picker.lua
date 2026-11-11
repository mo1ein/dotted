-- Dependency-free theme list: move to preview, Enter confirms, Esc/q cancels.
-- Native / search works in the list when fzf isn't installed.
local M = {}

function M.open(items, session)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, items)
  vim.bo[buf].modifiable = false
  local config = require "config.theme_picker"
  local width = math.max(1, math.min(config.native_width, vim.o.columns - 4))
  local height = math.max(1, math.min(config.native_rows, #items, vim.o.lines - 6))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded",
    width = width, height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    title = " Themes · / search · Enter confirm · Esc cancel ",
  })
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  local detach_hover = require("ui.statusline_hover").register(win, function(mouse)
    if mouse.line < 1 or mouse.line > #items then return end
    if vim.api.nvim_win_get_cursor(win)[1] ~= mouse.line then vim.api.nvim_win_set_cursor(win, { mouse.line, 0 }) end
    return mouse.line
  end)
  local function close(accept)
    local row = vim.api.nvim_win_get_cursor(win)[1]
    if accept then session.select(items[row]) else session.finish() end
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  for _, key in ipairs { "<Esc>", "q", "<C-c>" } do
    vim.keymap.set("n", key, function() close(false) end, { buffer = buf, nowait = true })
  end
  vim.keymap.set("n", "<CR>", function() close(true) end, { buffer = buf, nowait = true })
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then session.hover(items[vim.api.nvim_win_get_cursor(win)[1]]) end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf, once = true, callback = function()
      detach_hover()
      session.stop()
      vim.schedule(function() session.cancel_if_idle() end)
    end,
  })
  return { buf = buf, win = win }
end

return M
