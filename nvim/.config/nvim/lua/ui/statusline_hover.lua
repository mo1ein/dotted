-- Observe mouse motion without replacing user mappings or swallowing terminal
-- mouse events. Hit-test native tabline/statusline/winbar spans; widgets can
-- register their own actionable regions without executing actions on hover.
local M = {}
local hovered
local widgets = {}
local winbars = {}
function M.register_winbar(win, kind, callback) winbars[win] = { kind = kind, callback = callback } end
local namespace = vim.api.nvim_create_namespace "DottedStatuslineHover"
local move = vim.api.nvim_replace_termcodes("<MouseMove>", true, false, true)
local function repaint()
  vim.cmd.redrawstatus()
  vim.cmd.redrawtabline()
end
local function set_hover(next_hover)
  if vim.deep_equal(hovered, next_hover) then return end
  local previous = hovered
  hovered = next_hover
  if previous and previous.kind == "widget" and (not next_hover or next_hover.kind ~= "widget" or next_hover.win ~= previous.win) then
    local widget = widgets[previous.win]
    if widget and widget.leave then widget.leave() end
  end
  repaint()
end
function M.clear() set_hover(nil) end
function M.current() return hovered and vim.deepcopy(hovered) end
local function matches(kind, id, win)
  return hovered and hovered.kind == kind and hovered.id == id and (not win or hovered.win == win)
    and hovered.tab == vim.api.nvim_get_current_tabpage()
end
function M.breadcrumb(buf, ordinal)
  return hovered and hovered.kind == "breadcrumb" and hovered.buf == buf and hovered.ordinal == ordinal
    and hovered.tab == vim.api.nvim_get_current_tabpage()
end
function M.tools()
  return hovered and hovered.kind == "tools" and hovered.tab == vim.api.nvim_get_current_tabpage()
end
function M.buffer(buf) return matches("buffer", buf) end
function M.buffer_close(buf) return matches("buffer_close", buf) end
function M.dashboard() return matches("dashboard", 0) end
function M.tabpage(tab) return matches("tabpage", tab) end
function M.tool_button(win, id) return matches("tool_button", id, win) end
function M.register(win, hover, leave, click)
  if hovered and hovered.kind == "widget" and hovered.win == win then M.clear() end
  local widget = { buf = vim.api.nvim_win_get_buf(win), hover = hover, leave = leave, click = click }
  widgets[win] = widget
  return function()
    if widgets[win] ~= widget then return end
    if hovered and hovered.win == win then M.clear() end
    widgets[win] = nil
  end
end
local function hit(status, column, identify)
  for i, span in ipairs(status.highlights) do
    local target = identify(span.group)
    if target then
      local start = vim.fn.strdisplaywidth(status.str:sub(1, span.start))
      local following = status.highlights[i + 1]
      local ending = following and vim.fn.strdisplaywidth(status.str:sub(1, following.start)) or status.width
      if column >= start and column < ending then return target end
    end
  end
end
local function control(group)
  local kind, id = group:match("^DottedControl_([%w]+)_(%d+)")
  if kind then return { kind = kind, id = tonumber(id) } end
end
local function status_target(mouse)
  local status = vim.api.nvim_eval_statusline(vim.o.statusline, {
    winid = vim.api.nvim_get_current_win(), maxwidth = vim.o.columns, highlights = true,
  })
  local ordinal = 0
  return hit(status, mouse.screencol - 1, function(group)
    local breadcrumb = group == "DottedBreadcrumb" or group == "DottedBreadcrumbHover" or group == "DottedBreadcrumbActive"
    local tools = group == "DottedStatuslineTools" or group == "DottedStatuslineToolsHover"
    if breadcrumb then ordinal = ordinal + 1 end
    if breadcrumb or tools then
      return { kind = tools and "tools" or "breadcrumb", ordinal = ordinal, buf = require("ui.statusline").context().bufnr }
    end
  end)
end
local function tabline_target(mouse)
  local status = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = vim.o.columns, highlights = true })
  local targets = require("ui.bufferline").hover_targets()
  local buffer, page = 0, 0
  return hit(status, mouse.screencol - 1, function(group)
    if control(group) then return control(group) end
    if group == "DottedDashboardButton" or group == "DottedDashboardButtonHover" then return { kind = "dashboard", id = 0 } end
    if group == "DottedBufActive" or group == "DottedBufInactive" or group == "DottedBufHover" then
      buffer = buffer + 1
      return { kind = "buffer", id = targets.buffers[buffer] }
    end
    if group == "DottedBufNumber" or group == "DottedBufNumberActive" or group == "DottedBufNumberHover" then
      return { kind = "buffer", id = targets.buffers[buffer] }
    end
    if group == "DottedBufClose" or group == "DottedBufCloseActive" or group == "DottedBufCloseHover" then
      return { kind = "buffer_close", id = targets.buffers[buffer] }
    end
    if group == "DottedTabPageActive" or group == "DottedTabPageInactive" or group == "DottedTabPageHover" then
      page = page + 1
      return { kind = "tabpage", id = targets.tabs[page] }
    end
  end)
end
local function tool_target(mouse, win)
  local position = vim.api.nvim_win_get_position(win)
  if mouse.screenrow ~= position[1] + 1 then return end
  local status = vim.api.nvim_eval_statusline(vim.wo[win].winbar, {
    winid = win, use_winbar = true, maxwidth = vim.api.nvim_win_get_width(win), highlights = true,
  })
  local ids, ordinal = require("ui.tools").button_ids(win), 0
  return hit(status, mouse.screencol - position[2] - 1, function(group)
    if control(group) then local value = control(group); value.win = win; return value end
    if group == "DottedToolActive" or group == "DottedToolInactive" or group == "DottedToolHover" then
      ordinal = ordinal + 1
      return { kind = "tool_button", id = ids[ordinal], win = win }
    end
  end)
end
M.winbar_target = tool_target
function M.update()
  local mouse, target = vim.fn.getmousepos(), nil
  local top = vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  if top and mouse.screenrow == 1 and vim.o.tabline == "%!v:lua.require('ui.bufferline').render()" then
    target = tabline_target(mouse)
  elseif vim.o.laststatus == 3 and mouse.screenrow == vim.o.lines - vim.o.cmdheight then
    target = status_target(mouse)
  elseif mouse.winid > 0 and vim.api.nvim_win_is_valid(mouse.winid) then
    if mouse.line == 0 then target = tool_target(mouse, mouse.winid) end
    local widget = widgets[mouse.winid]
    if not target and widget and widget.buf == vim.api.nvim_win_get_buf(mouse.winid) and mouse.line > 0 then
      local id = widget.hover(mouse)
      if id then target = { kind = "widget", id = id, win = mouse.winid } end
    end
  end
  if target then target.tab = vim.api.nvim_get_current_tabpage() end
  set_hover(target)
end
function M.setup()
  local group = vim.api.nvim_create_augroup("DottedStatuslineHover", { clear = true })
  local function highlights()
    vim.api.nvim_set_hl(0, "DottedBreadcrumbHover", { link = "DottedBreadcrumbSelection" })
    vim.api.nvim_set_hl(0, "DottedStatuslineTools", { link = "DottedSt_file" })
    vim.api.nvim_set_hl(0, "DottedStatuslineToolsHover", { link = "DottedBreadcrumbSelection" })
  end
  highlights()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "BufDelete", "TabEnter", "TabClosed", "WinResized", "VimResized", "FocusLost" }, { group = group, callback = M.clear })
  vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(args)
    local win = tonumber(args.match)
    if hovered and hovered.win == win then M.clear() end
    widgets[win], winbars[win] = nil, nil
  end })
  vim.o.mousemoveevent = true
  local queued = false
  local click = vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true)
  vim.on_key(function(key, typed)
    local name = vim.fn.keytrans(key)
    if name:find("LeftMouse", 1, true) or name == "<LeftRelease>" or name == "<LeftDrag>" then
      local mouse = vim.fn.getmousepos()
      if mouse.screenrow == 1 and vim.o.showtabline == 2 then
        local target = tabline_target(mouse)
        if target and target.kind == "run" then
          if name:find("LeftMouse", 1, true) then _G.DottedRunControlClick(target.id) end
          return ""
        end
      end
      local handler = winbars[mouse.winid]
      if handler and mouse.line == 0 and vim.api.nvim_win_is_valid(mouse.winid) then
        local target = tool_target(mouse, mouse.winid)
        if target and target.kind == handler.kind then
          if name:find("LeftMouse", 1, true) then vim.schedule(function() handler.callback(target.id) end) end
          return ""
        end
      end
    end
    if key:find(click, 1, true) or (typed or ""):find(click, 1, true) then
      vim.schedule(function()
        local mouse = vim.fn.getmousepos()
        local widget = widgets[mouse.winid]
        if widget and widget.click and mouse.line > 0 then widget.click(mouse) end
      end)
    end
    if not (key:find(move, 1, true) or (typed or ""):find(move, 1, true)) or queued then return end
    queued = true
    vim.schedule(function() queued = false; M.update() end)
  end, namespace)
end
return M
