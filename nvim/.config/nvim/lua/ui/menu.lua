-- Small native mouse/keyboard menu shared by breadcrumbs and tool selectors.
local M = {}
local active
local hidden_cursor = "a:ver1-blinkon0-DottedMenuCursor"
local function highlights()
  local colors = require "ui.color"
  local bg = colors.get(active and active.selection or "PmenuSel").bg or colors.get("NormalFloat").bg or colors.get("Normal").bg
  vim.api.nvim_set_hl(0, "DottedMenuCursor", { fg = bg, bg = bg, blend = 100, nocombine = true })
end
function M.open(opts)
  if active then active:close() end
  local menu = { source = opts.source or vim.api.nvim_get_current_win(), items = opts.items or {}, title = opts.title, anchor = opts.anchor }
  menu.selection = opts.selection or "PmenuSel"
  active = menu
  menu.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[menu.buf].bufhidden = "wipe"
  vim.bo[menu.buf].filetype = "dotted_menu"
  local group = vim.api.nvim_create_augroup("DottedMenu" .. menu.buf, { clear = true })
  local cursor, mousemove
  local function release()
    if cursor ~= nil and vim.o.guicursor == hidden_cursor then vim.o.guicursor = cursor end
    if mousemove ~= nil and vim.o.mousemoveevent then vim.o.mousemoveevent = mousemove end
    cursor, mousemove = nil, nil
  end
  local function acquire()
    cursor, mousemove = vim.o.guicursor, vim.o.mousemoveevent
    highlights()
    vim.o.guicursor, vim.o.mousemoveevent = hidden_cursor, true
  end
  local function finish()
    if menu.closed then return end
    menu.closed = true
    release()
    if active == menu then active = nil end
    vim.api.nvim_del_augroup_by_id(group)
    if opts.on_close then opts.on_close(menu) end
  end
  function menu:close()
    if self.closed then return end
    local restore = self.win == vim.api.nvim_get_current_win()
    finish()
    if self.win and vim.api.nvim_win_is_valid(self.win) then vim.api.nvim_win_close(self.win, true) end
    if restore and vim.api.nvim_win_is_valid(self.source) then vim.api.nvim_set_current_win(self.source) end
  end
  function menu:update(items, title)
    if self.closed or not vim.api.nvim_buf_is_valid(self.buf) then return end
    self.items, self.title = items, title or self.title
    local lines, width = {}, 20
    for _, item in ipairs(items) do
      local line = tostring(item.label):gsub("[%c]", " ")
      lines[#lines + 1] = " " .. line .. " "
      width = math.max(width, vim.fn.strdisplaywidth(line) + 2)
    end
    if #lines == 0 then lines = { " (empty) " } end
    vim.bo[self.buf].modifiable = true
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
    vim.bo[self.buf].modifiable = false
    local w = math.max(1, math.min(width, vim.o.columns - 2))
    local h = math.max(1, math.min(#lines, math.floor(vim.o.lines * 0.45)))
    local row, col = math.max(0, vim.o.lines - h - 4), math.max(0, math.floor((vim.o.columns - w) / 2))
    if self.anchor and self.anchor.placement == "below" then
      row = self.anchor.row + 1
      if row + h + 2 > vim.o.lines - vim.o.cmdheight then row = math.max(0, self.anchor.row - h - 2) end
      col = math.max(0, math.min(self.anchor.col, vim.o.columns - w - 2))
    elseif self.anchor then
      local bottom = math.max(3, math.min(self.anchor.row, vim.o.lines - vim.o.cmdheight - 1))
      h = math.max(1, math.min(h, bottom - 2))
      row = math.max(0, bottom - h - 2)
      col = math.max(0, math.min(self.anchor.col, vim.o.columns - w - 2))
    end
    local config = {
      relative = "editor", style = "minimal", border = "rounded", width = w, height = h,
      row = row, col = col,
      zindex = 150,
    }
    if self.title then
      config.title = " " .. tostring(self.title):gsub("[%c]", " ") .. " "
      config.title_pos = "center"
    end
    if self.win and vim.api.nvim_win_is_valid(self.win) then vim.api.nvim_win_set_config(self.win, config)
    else self.win = vim.api.nvim_open_win(self.buf, true, config) end
    vim.wo[self.win].cursorline = true
    vim.wo[self.win].cursorlineopt = "line"
    vim.wo[self.win].wrap = false
    vim.wo[self.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:" .. self.selection
    vim.api.nvim_win_set_cursor(self.win, { 1, 0 })
  end
  local function choose()
    if not menu.win or not vim.api.nvim_win_is_valid(menu.win) then return end
    local item = menu.items[vim.api.nvim_win_get_cursor(menu.win)[1]]
    if item and item.action then item.action(menu) end
  end
  local function map(keys, action)
    for _, key in ipairs(type(keys) == "table" and keys or { keys }) do
      vim.keymap.set("n", key, action, { buffer = menu.buf, silent = true, nowait = true })
    end
  end
  map("<MouseMove>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid == menu.win and mouse.line >= 1 and mouse.line <= #menu.items then
      -- Hover only selects. It must never open a file or descend a directory.
      vim.api.nvim_win_set_cursor(menu.win, { mouse.line, 0 })
    end
  end)
  local function move(delta)
    local row = vim.api.nvim_win_get_cursor(menu.win)[1]
    vim.api.nvim_win_set_cursor(menu.win, { math.max(1, math.min(#menu.items, row + delta)), 0 })
  end
  map({ "j", "<Down>" }, function() move(1) end)
  map({ "k", "<Up>" }, function() move(-1) end)
  map({ "q", "<Esc>" }, function() menu:close() end)
  map({ "<CR>", "<Right>", "l" }, choose)
  if opts.parent then map({ "<Left>", "h", "<BS>" }, function() opts.parent(menu) end) end
  map("<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    if mouse.winid == menu.win and mouse.line >= 1 and mouse.line <= #menu.items then
      vim.api.nvim_win_set_cursor(menu.win, { mouse.line, 0 })
      choose()
    elseif mouse.winid ~= menu.win then
      if opts.on_outside_click and opts.on_outside_click(menu, mouse) then return end
      menu:close()
      -- Our buffer-local mouse map consumed the click. Replay it after closing
      -- so another breadcrumb (or editor window) receives the original action.
      if mouse.screenrow > 0 and mouse.screencol > 0 then
        vim.api.nvim_input_mouse("left", "press", "", 0, mouse.screenrow - 1, mouse.screencol - 1)
        vim.api.nvim_input_mouse("left", "release", "", 0, mouse.screenrow - 1, mouse.screencol - 1)
      end
    end
  end)
  menu:update(menu.items, menu.title)
  acquire()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  vim.api.nvim_create_autocmd("WinLeave", { group = group, callback = function()
    if vim.api.nvim_get_current_win() ~= menu.win then return end
    release()
    vim.schedule(function()
      if not menu.closed and vim.api.nvim_get_current_win() ~= menu.win then menu:close() end
    end)
  end })
  vim.api.nvim_create_autocmd("WinEnter", { group = group, callback = function()
    if vim.api.nvim_get_current_win() == menu.win and cursor == nil then acquire() end
  end })
  vim.api.nvim_create_autocmd("WinClosed", { group = group, pattern = tostring(menu.win), callback = finish })
  vim.api.nvim_create_autocmd("BufWipeout", { group = group, buffer = menu.buf, callback = finish })
  return menu
end
return M
