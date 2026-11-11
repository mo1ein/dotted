-- Owned, non-focusable MRU popup. Preview in the source; commit on release.
local M = {}
local active, previewing
local namespace = vim.api.nvim_create_namespace "DottedSwitcher"
local selection = "DottedBreadcrumbSelection" -- shared finder/theme hover palette
local function valid(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and vim.bo[buf].buftype == ""
end
local function owns_source(s)
  return vim.api.nvim_get_current_win() == s.source and require("ui.buffers").is_source(s.source)
    and vim.api.nvim_win_get_buf(s.source) == s.selected
end

function M.current() return active end

function M.finish(cancel)
  local s = active
  if not s then return end
  active = nil -- invalidate queued release/input callbacks before any autocmds
  vim.on_key(nil, namespace)
  if s.stop then s.stop() end
  if s.win and vim.api.nvim_win_is_valid(s.win) then pcall(vim.api.nvim_win_close, s.win, true) end
  if vim.api.nvim_buf_is_valid(s.buf) then pcall(vim.api.nvim_buf_delete, s.buf, { force = true }) end
  if not owns_source(s) then return end
  if cancel and valid(s.original) then
    local registry = require "ui.buffers"
    local suspended = registry.suspend_touch
    registry.suspend_touch = true
    pcall(vim.api.nvim_win_set_buf, s.source, s.original)
    vim.fn.winrestview(s.view)
    registry.suspend_touch = suspended
  elseif not cancel and valid(s.selected) then
    require("ui.buffers").touch(s.selected)
  end
end

local function paint(s)
  vim.api.nvim_buf_clear_namespace(s.buf, namespace, 0, -1)
  for _, row in ipairs { s.index, s.hovered } do
    if row then
      local text = vim.api.nvim_buf_get_lines(s.buf, row - 1, row, false)[1]
      if text then
        vim.api.nvim_buf_set_extmark(s.buf, namespace, row - 1, 0, {
          end_col = #text, hl_group = selection, line_hl_group = selection, hl_eol = true, priority = 200,
        })
      end
    end
  end
end

local function hover(s)
  local mouse, row = vim.fn.getmousepos(), nil
  local position = vim.api.nvim_win_get_position(s.win)
  local top, left = position[1] + 1, position[2] + 1 -- rounded border
  if mouse.screenrow > top and mouse.screenrow <= top + vim.api.nvim_win_get_height(s.win)
    and mouse.screencol > left and mouse.screencol <= left + vim.api.nvim_win_get_width(s.win) then
    local info = vim.fn.getwininfo(s.win)[1]
    row = info.topline + mouse.screenrow - top - 1
    if row > #s.buffers then row = nil end
  end
  if row ~= s.hovered then s.hovered = row; paint(s) end
end

local function render(s)
  local lines, width = {}, 24
  local icons = require "nvim-web-devicons"
  for _, buf in ipairs(s.buffers) do
    local name = vim.api.nvim_buf_get_name(buf)
    local tail = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t")
    local icon = icons.get_icon(tail, vim.fn.fnamemodify(name, ":e"), { default = true })
    local parent = name == "" and "" or vim.fn.fnamemodify(name, ":h:t") .. "/"
    local line = (" %s %s%s%s "):format(icon or "", parent, tail, vim.bo[buf].modified and " ●" or "")
    lines[#lines + 1] = line:gsub("[%c]", " ")
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local w = math.max(1, math.min(width, math.floor(vim.o.columns * 0.6)))
  local h = math.max(1, math.min(#lines, 9, vim.o.lines - 4))
  vim.bo[s.buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, lines)
  vim.bo[s.buf].modifiable = false
  local config = { relative = "editor", style = "minimal", border = "rounded", focusable = false,
    title = " Switcher ", title_pos = "center",
    width = w, height = h, row = math.max(0, math.floor((vim.o.lines - h - 2) / 2) - 3),
    col = math.max(0, math.floor((vim.o.columns - w - 2) / 2)), zindex = 150 }
  if s.win then vim.api.nvim_win_set_config(s.win, config)
  else
    s.win = vim.api.nvim_open_win(s.buf, false, config)
    vim.wo[s.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:" .. selection
    vim.wo[s.win].cursorline, vim.wo[s.win].cursorlineopt = true, "line"
    vim.wo[s.win].wrap, vim.wo[s.win].scrolloff = false, 0
  end
  vim.api.nvim_win_set_cursor(s.win, { s.index, 0 })
  -- Extmarks also paint the selected row when this non-focusable window is
  -- inactive (including insert mode). Both roles resolve live after a theme change.
  paint(s)
end

function M.cycle(direction)
  local registry = require "ui.buffers"
  if active and not owns_source(active) then M.finish() end
  if not active then
    local win, buffers = registry.source_win(), registry.recent()
    if not win or #buffers < 2 then return end
    vim.api.nvim_set_current_win(win)
    local original = vim.api.nvim_win_get_buf(win)
    active = { source = win, original = original, selected = original, view = vim.fn.winsaveview(),
      buffers = buffers, index = vim.fn.index(buffers, original) + 1, buf = vim.api.nvim_create_buf(false, true) }
    vim.bo[active.buf].bufhidden, vim.bo[active.buf].filetype = "wipe", "dotted_switcher"
  end
  local s = active
  s.index = (s.index - 1 + (direction == "prev" and -1 or 1)) % #s.buffers + 1
  local suspended = registry.suspend_touch
  previewing, registry.suspend_touch = true, true
  local ok, err = pcall(function()
    s.selected = s.buffers[s.index]
    vim.api.nvim_win_set_buf(s.source, s.selected)
    render(s)
  end)
  previewing, registry.suspend_touch = false, suspended
  if not ok then M.finish(true); error(err) end
  if not s.listening then
    s.listening = true
    local cycling_keys = {}
    for _, entry in ipairs(require("keymaps").current().bindings) do
      if entry.action == "buffer.recent_next" or entry.action == "buffer.recent_prev" then
        for _, chord in ipairs(entry.keys) do cycling_keys[vim.fn.keytrans(vim.keycode(chord))] = true end
      end
    end
    -- Only consume confirm/cancel while open; never replace global/buffer maps.
    vim.on_key(function(key, typed)
      if active ~= s then return end
      local input = vim.fn.keytrans(typed ~= "" and typed or key)
      if input:find("MouseMove", 1, true) then
        -- The popup remains mouse-transparent: hover is visual only and cannot
        -- focus it, preview another buffer, or change the release selection.
        vim.schedule(function() if active == s then hover(s) end end)
        return
      end
      local cancel = input == "<Esc>"
      local confirm = input == "<CR>"
      if cancel or confirm then
        vim.schedule(function() if active == s then M.finish(cancel) end end)
        return ""
      end
      -- Existing preset mappings own cycling. Other input confirms then runs
      -- normally, including mouse actions; hover must not dismiss the popup.
      if typed ~= "" and not cycling_keys[input]
        and not input:find("MouseMove", 1, true) then
        vim.schedule(function() if active == s then M.finish() end end)
      end
    end, namespace)
    s.stop = require("ui.modifiers").watch("alt", function() if active == s then M.finish() end end)
  end
end

function M.setup()
  M.finish()
  local group = vim.api.nvim_create_augroup("DottedSwitcher", { clear = true })
  vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "FocusLost", "VimLeavePre" }, { group = group, callback = function()
    if active and not previewing then M.finish() end
  end })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, { group = group, callback = function(args)
    if active and (args.buf == active.buf or vim.tbl_contains(active.buffers, args.buf)) then M.finish() end
  end })
  vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(args)
    if active and (tonumber(args.match) == active.win or tonumber(args.match) == active.source) then M.finish() end
  end })
  vim.api.nvim_create_autocmd("VimResized", { group = group, callback = function() if active then render(active) end end })
end
return M
