-- Small modal Yes/No box. Defaults to No; closes without saving on Escape/q.
local M = {}

function M.open(message, callback)
  local api = vim.api
  local lines = { "", "  " .. message, "  Save as the default for future sessions?", "", "  [ Yes, save ]   [ No, restore ]", "" }
  local width = 42
  for _, line in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(line) + 2) end
  width = math.max(1, math.min(width, vim.o.columns - 4))
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "theme-confirm"
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local height = math.max(1, math.min(#lines, vim.o.lines - 4))
  local win = api.nvim_open_win(buf, true, {
    relative = "editor", style = "minimal", border = "rounded", title = " Confirm theme ",
    width = width, height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  })
  local namespace = api.nvim_create_namespace "ThemeConfirmation"
  local choice, resolved, hovered = 2, false, nil
  local buttons = { { 2, 15 }, { 18, 33 } }
  local function draw()
    api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for i, range in ipairs(buttons) do
      api.nvim_buf_set_extmark(buf, namespace, 4, range[1], {
        end_col = range[2], hl_group = i == hovered and "DottedBreadcrumbSelection" or i == choice and "PmenuSel" or "Comment",
      })
    end
    api.nvim_win_set_cursor(win, { 5, buttons[choice][1] })
  end
  local detach_hover = require("ui.statusline_hover").register(win, function(mouse)
    if resolved or mouse.line ~= 5 then return end
    for i, range in ipairs(buttons) do
      if mouse.column > range[1] and mouse.column <= range[2] then
        if hovered ~= i then hovered = i; draw() end
        return i
      end
    end
  end, function()
    hovered = nil
    if not resolved and api.nvim_buf_is_valid(buf) and api.nvim_win_is_valid(win) then draw() end
  end)
  local function finish(answer)
    if resolved then return end
    resolved = true
    detach_hover()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    callback(answer)
  end
  local function map(keys, fn)
    for _, key in ipairs(keys) do vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true }) end
  end
  map({ "<Left>", "h" }, function() choice = 1; draw() end)
  map({ "<Right>", "l" }, function() choice = 2; draw() end)
  map({ "<Tab>", "<S-Tab>" }, function() choice = choice % 2 + 1; draw() end)
  map({ "<CR>" }, function() finish(choice == 1) end)
  map({ "y", "Y" }, function() finish(true) end)
  map({ "n", "N", "<Esc>", "q", "<C-c>" }, function() finish(false) end)
  map({ "<LeftMouse>" }, function()
    local pos = vim.fn.getmousepos()
    if pos.winid ~= win or pos.line ~= 5 then return end
    for i, range in ipairs(buttons) do
      if pos.column > range[1] and pos.column <= range[2] then finish(i == 1); return end
    end
  end)
  api.nvim_create_autocmd("BufWipeout", {
    buffer = buf, once = true,
    callback = function()
      detach_hover()
      if not resolved then resolved = true; vim.schedule(function() callback(false) end) end
    end,
  })
  draw()
  return { buf = buf, win = win }
end

return M
