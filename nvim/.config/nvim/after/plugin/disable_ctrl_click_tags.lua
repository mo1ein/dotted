-- Ctrl+Click to open URLs under cursor (replaces default tag lookup)
local function open_url_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col(".") - 1

  -- find URL pattern around cursor
  local url_pattern = "https?://[%w%-%.%/:%?&=%+_#@]+"
  local start = 1
  while start <= #line do
    local s, e = line:find(url_pattern, start)
    if not s then break end
    if col >= s - 1 and col <= e then
      local url = line:sub(s, e)
      vim.ui.open(url)
      return
    end
    start = e + 1
  end
end

vim.keymap.set("n", "<C-LeftMouse>", open_url_under_cursor, { noremap = true, silent = true })
