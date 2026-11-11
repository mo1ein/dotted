-- Shared native winbar/tabline buttons. Every icon has its own hover region.
local M = {}
function M.button(kind, id, label, callback, active, role)
  local base = "DottedControl_" .. kind .. "_" .. id
  local target = role or "DottedToolInactive"
  if vim.api.nvim_get_hl(0, { name = base, link = true, create = false }).link ~= target then
    vim.api.nvim_set_hl(0, base, { link = target })
  end
  vim.api.nvim_set_hl(0, base .. "Active", { link = "DottedToolActive", default = true })
  vim.api.nvim_set_hl(0, base .. "Hover", { link = "DottedBreadcrumbSelection", default = true })
  local h = require("ui.statusline_hover").current()
  local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
  local hover = h and h.kind == kind and h.id == id and (not h.win or h.win == win)
  return ("%%#%s#%%%d@v:lua.%s@ %s %%X%%#DottedToolPadInactive#"):format(hover and base .. "Hover" or active and base .. "Active" or base, id, callback, label)
end
function M.attach_winbar(buf, win, kind, callback)
  if type(win) == "number" and vim.api.nvim_win_get_config(win).relative ~= "" then
    require("ui.statusline_hover").register_winbar(win, kind, callback)
  end
  local function target()
    local mouse = vim.fn.getmousepos()
    local target_win = type(win) == "function" and win() or win
    return mouse.winid == target_win and require("ui.statusline_hover").winbar_target(mouse, target_win)
  end
  for _, key in ipairs { "<LeftMouse>", "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>" } do
    vim.keymap.set({ "n", "i", "x" }, key, function()
      local hit = target()
      if hit and hit.kind == kind then callback(hit.id); return "" end
      return key
    end, { buffer = buf, expr = true, replace_keycodes = true })
  end
  for _, key in ipairs { "<LeftRelease>", "<LeftDrag>" } do
    vim.keymap.set({ "n", "i", "x" }, key, function()
      local hit = target()
      return hit and hit.kind == kind and "" or key
    end, { buffer = buf, expr = true, replace_keycodes = true })
  end
end
function M.anchor(kind, id, win)
  if not win or not vim.api.nvim_win_is_valid(win) then return nil end
  local status = vim.api.nvim_eval_statusline(vim.wo[win].winbar, {
    winid = win, use_winbar = true, maxwidth = vim.api.nvim_win_get_width(win), highlights = true,
  })
  local pos = vim.api.nvim_win_get_position(win)
  for _, span in ipairs(status.highlights) do
    if span.group == "DottedControl_" .. kind .. "_" .. id or span.group == "DottedControl_" .. kind .. "_" .. id .. "Hover" or span.group == "DottedControl_" .. kind .. "_" .. id .. "Active" then
      return { row = pos[1], col = pos[2] + vim.fn.strdisplaywidth(status.str:sub(1, span.start)), placement = "below" }
    end
  end
end
function M.select(title, choices, callback, anchor)
  local items = {}
  for _, choice in ipairs(choices) do
    items[#items + 1] = { label = choice, action = function(menu) menu:close(); callback(choice) end }
  end
  return require("ui.menu").open { title = title, items = items, anchor = anchor }
end
function M.input(title, value, callback, anchor)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "dotted_input"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { value or "" })
  local w = math.max(1, math.min(70, vim.o.columns - 4))
  local win = vim.api.nvim_open_win(buf, true, { relative = "editor", style = "minimal", border = "rounded",
    width = w, height = 1, row = anchor and math.min(anchor.row + 1, vim.o.lines - 5) or 3,
    col = anchor and math.max(0, math.min(anchor.col, vim.o.columns - w - 2)) or math.max(0, math.floor((vim.o.columns - w) / 2)),
    title = " " .. title .. " ", footer = " Enter: create   Esc: cancel ", zindex = 180 })
  local function finish(accept)
    local text = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    vim.cmd.stopinsert()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if accept and text ~= "" then callback(text) end
  end
  for _, mode in ipairs { "n", "i" } do
    vim.keymap.set(mode, "<CR>", function() finish(true) end, { buffer = buf })
    vim.keymap.set(mode, "<Esc>", function() finish(false) end, { buffer = buf })
  end
  vim.api.nvim_win_set_cursor(win, { 1, #(value or "") })
  vim.cmd.startinsert { bang = true }
  return { buf = buf, win = win }
end
return M
