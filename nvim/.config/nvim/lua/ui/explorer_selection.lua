-- Keep the active editor file visible while tree navigation uses whole rows.
local M = {}
local namespace = vim.api.nvim_create_namespace "DottedExplorerSelection"
local hidden_cursor = "a:ver1-blinkon0-DottedExplorerCursor"
local saved_cursor, group, queued
local rows = {}
local function api() return require "nvim-tree.api" end
local function tree_focused() return vim.bo.filetype == "NvimTree" or vim.bo.filetype == "NvimTreeSearch" end
local function release_cursor()
  if saved_cursor and vim.o.guicursor == hidden_cursor then vim.o.guicursor = saved_cursor end
  saved_cursor = nil
end
local function cursor()
  if tree_focused() then
    if not saved_cursor then saved_cursor = vim.o.guicursor; vim.o.guicursor = hidden_cursor end
  else release_cursor() end
end
local function highlights()
  -- Follow the live editor role, including overrides applied after ColorScheme.
  vim.api.nvim_set_hl(0, "DottedExplorerSelection", { link = "CursorLine" })
  vim.api.nvim_set_hl(0, "DottedExplorerActive", { link = "CursorLine" })
  local bg = require("ui.color").get("CursorLine").bg
  vim.api.nvim_set_hl(0, "DottedExplorerCursor", { fg = bg, bg = bg, blend = 100, nocombine = true })
end
local function source_path()
  local win = require("ui.buffers").source_win()
  if not win then return end
  local path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
  if path ~= "" then return vim.uv.fs_realpath(path) or path end
end
local function mark(buf, id, row, highlight)
  if row then
    vim.api.nvim_buf_set_extmark(buf, namespace, row - 1, 0, { id = id, line_hl_group = highlight, priority = 90 })
  else pcall(vim.api.nvim_buf_del_extmark, buf, namespace, id) end
end
local function paint(data)
  local buf, win = data.bufnr, data.winnr
  if not win or not vim.api.nvim_win_is_valid(win) then return end
  local visible = {}
  local function walk(nodes)
    for _, node in ipairs(nodes or {}) do
      if not node.hidden then
        visible[#visible + 1] = node
        if node.open then walk(node.nodes) end
      end
    end
  end
  walk(api().tree.get_nodes().nodes)
  -- The remaining lines are NvimTree's optional root/filter headers.
  local offset = vim.api.nvim_buf_line_count(buf) - #visible
  local current, selected = source_path(), nil
  rows[win] = {}
  for i, node in ipairs(visible) do
    rows[win][offset + i] = node
    if node.absolute_path == current then selected = offset + i end
  end
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  mark(buf, 1, selected, "DottedExplorerActive")
end
local function refresh()
  queued = false
  local win = api().tree.winid()
  if not win then return end
  vim.wo[win].cursorline = vim.api.nvim_get_current_win() == win
  vim.wo[win].cursorlineopt = "line"
  vim.wo[win].winhighlight = vim.wo[win].winhighlight:gsub("CursorLine:[^,]+", "CursorLine:DottedExplorerSelection")
  local path = source_path()
  if path and require("ui.explorer").follow then api().tree.find_file { buf = path, open = false, focus = false } end
  paint { bufnr = vim.api.nvim_win_get_buf(win), winnr = win }
end
local function schedule_refresh()
  if queued then return end
  queued = true
  vim.schedule(refresh)
end
function M.setup()
  if group then return end
  group = vim.api.nvim_create_augroup("DottedExplorerSelection", { clear = true })
  highlights()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TabEnter" }, { group = group, callback = function()
    cursor()
    schedule_refresh()
  end })
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave", "VimLeavePre" }, { group = group, callback = release_cursor })
  vim.api.nvim_create_autocmd("CmdlineEnter", { group = group, callback = release_cursor })
  vim.api.nvim_create_autocmd("CmdlineLeave", { group = group, callback = cursor })
  vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(args) rows[tonumber(args.match)] = nil end })
  api().events.subscribe(api().events.Event.TreeRendered, paint)
  api().events.subscribe(api().events.Event.TreeOpen, function()
    local win = api().tree.winid()
    if not win then return end
    local buf = vim.api.nvim_win_get_buf(win)
    require("ui.statusline_hover").register(win, function(mouse)
      if not (rows[win] and rows[win][mouse.line]) then return end
      mark(buf, 2, mouse.line, "DottedExplorerSelection")
      if vim.api.nvim_get_current_win() == win then vim.api.nvim_win_set_cursor(win, { mouse.line, 0 }) end
      return mouse.line
    end, function()
      if vim.api.nvim_buf_is_valid(buf) then mark(buf, 2, nil) end
    end)
    cursor()
    schedule_refresh()
  end)
end
return M
