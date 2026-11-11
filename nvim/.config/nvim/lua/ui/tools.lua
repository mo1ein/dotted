-- One persistent drawer per tabpage. Switching tools swaps buffers, never the
-- split layout; the drawer sits below the editor, not across explorer sidebars.
local M = {}
local tabs = { "Debug", "Output", "Problems", "Terminal" }
local states = {}
local header_targets = {}
function M.button_ids(win) return header_targets[win] or {} end
local options = {
  "number", "relativenumber", "signcolumn", "foldcolumn", "foldenable", "foldmethod",
  "statuscolumn", "winbar", "winhighlight", "winfixheight", "winfixwidth", "wrap",
  "spell", "list", "cursorline", "scrolloff", "sidescrolloff", "winblend",
}
local function state()
  local tab = vim.api.nvim_get_current_tabpage()
  states[tab] = states[tab] or { tab = tab, selected = "Terminal", height = require("config.ui").tools.height, views = {} }
  return states[tab]
end
local function valid(win) return win and vim.api.nvim_win_is_valid(win) end
local function owns(s)
  return valid(s.win) and vim.w[s.win].dotted_tool == s.tab and vim.api.nvim_win_get_buf(s.win) == s.buf
end
local function source(s)
  local main = require("ui.buffers").source_win()
  if main then return main end
  if require("ui.buffers").is_source(s.source) and vim.api.nvim_win_get_tabpage(s.source) == s.tab then return s.source end
end
local function height(s)
  return math.max(2, math.min(s.minimized and 2 or s.height, math.floor(vim.o.lines * 0.6)))
end
local function close_strip(s)
  local win = s.strip
  s.strip = nil
  if valid(win) then vim.api.nvim_win_close(win, true) end
end
local function detach(s)
  close_strip(s)
  -- A user can repurpose a drawer window. Give it back its original editor
  -- options rather than closing it or leaving the tool header over their file.
  if valid(s.win) and vim.w[s.win].dotted_tool == s.tab then
    vim.w[s.win].dotted_tool = nil
    for name, value in pairs(s.base_options or {}) do vim.wo[s.win][name] = value end
  end
  s.win, s.buf, s.ready = nil, nil, false
end
local function save_view(s)
  if owns(s) then s.views[s.buf] = vim.api.nvim_win_call(s.win, vim.fn.winsaveview) end
end
local function placeholder(s, name, lines)
  s.empty = s.empty or {}
  local buf = s.empty[name]
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype, vim.bo[buf].bufhidden = "dotted_tools", "hide"
    s.empty[name] = buf
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return buf
end

function M.is_open() local s = state(); return s.ready and owns(s) or false end
function M.current() return state() end

local function configure(s)
  local win, buf = s.win, s.buf
  vim.w[win].dotted_tool = s.tab
  for name, value in pairs {
    winbar = "", number = false, relativenumber = false,
    signcolumn = "no", foldcolumn = "0", foldenable = false, foldmethod = "manual", statuscolumn = "",
    winfixheight = true, winfixwidth = false, wrap = false, spell = false, list = false,
    cursorline = s.selected == "Problems", scrolloff = 0, sidescrolloff = 0, winblend = 0,
    winhighlight = "Normal:NormalFloat,EndOfBuffer:NormalFloat,WinBar:DottedToolInactive,WinBarNC:DottedToolInactive",
  } do vim.wo[win][name] = value end
  -- Scratch providers may be entered before filetype is set. Identity prefixes
  -- prevent already-queued which-key triggers from stealing local tool keys.
  for _, prefix in ipairs { "g", "z", "[", "]", "<Space>", "<C-w>" } do
    vim.keymap.set("n", prefix, prefix, { buffer = buf, silent = true, nowait = false, desc = "native tool key prefix" })
  end
  local function map(key, action) vim.keymap.set("n", key, action, { buffer = buf, silent = true, nowait = true }) end
  for index, name in ipairs(tabs) do map("g" .. index, function() M.show(name) end) end
  map("gq", M.hide)
  map("gm", M.minimize)
  map("gL", M.choose)
  map("g+", M.new_terminal)
  map("]T", function() M.cycle_terminal(1) end)
  map("[T", function() M.cycle_terminal(-1) end)
  map("]t", function() M.cycle(1) end)
  map("[t", function() M.cycle(-1) end)
  if s.selected == "Problems" then require("ui.problems").attach_hover(s) end
end

local strip_ns = vim.api.nvim_create_namespace "DottedTerminalTabs"
local function render_strip(s, hovered)
  if not valid(s.strip) then return end
  local buf = vim.api.nvim_win_get_buf(s.strip)
  local text, spans = "", {}
  if s.selected == "Terminal" then
    local shell = vim.fn.fnamemodify(vim.o.shell, ":t")
    for i, terminal in ipairs(s.terminals or {}) do
      if vim.api.nvim_buf_is_valid(terminal) then
        local label = " " .. shell .. (i > 1 and (" " .. i) or "") .. " "
        spans[#spans + 1] = { start = #text, finish = #text + #label, buf = terminal, id = i }
        text = text .. label .. " "
      end
    end
  else
    local task = package.loaded["ui.output"] and require("ui.output").selected
    text = s.selected == "Output" and task and (" " .. task.name) or (" " .. s.selected)
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  vim.api.nvim_buf_clear_namespace(buf, strip_ns, 0, -1)
  for _, span in ipairs(spans) do
    vim.api.nvim_buf_set_extmark(buf, strip_ns, 0, span.start, { end_col = span.finish,
      hl_group = hovered == span.id and "DottedToolHover" or s.terminal == span.buf and "DottedToolActive" or "DottedToolInactive" })
  end
  vim.bo[buf].modifiable = false
  s.session_spans = spans
end
local function configure_strip(s)
  if not valid(s.strip) then
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden, vim.bo[buf].filetype = "wipe", "dotted_tool_tabs"
    s.strip = vim.api.nvim_open_win(buf, false, { split = "above", win = s.win, height = 1 })
    vim.w[s.strip].dotted_tool = s.tab
    for name, value in pairs { number = false, relativenumber = false, signcolumn = "no", statuscolumn = "",
      foldcolumn = "0", winfixheight = true, cursorline = false, wrap = false, list = false,
      winbar = "%!v:lua.require('ui.tools').header()", winhighlight = "Normal:DottedToolInactive,WinBar:DottedToolInactive,WinBarNC:DottedToolInactive" } do
      vim.wo[s.strip][name] = value
    end
    local function hit(mouse)
      for _, span in ipairs(s.session_spans or {}) do
        local byte = vim.fn.byteidx(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], mouse.column - 1)
        if byte >= span.start and byte < span.finish then return span end
      end
    end
    require("ui.statusline_hover").register(s.strip, function(mouse)
      local span = hit(mouse)
      render_strip(s, span and span.id)
      return span and span.id
    end, function() render_strip(s) end, function(mouse)
      local span = hit(mouse)
      if span then s.terminal = span.buf; M.show("Terminal") end
    end)
  end
  render_strip(s)
end
local function mount(s, buf, focus)
  if not owns(s) then
    detach(s)
    local main = source(s)
    if not main then
      local empty = vim.api.nvim_create_buf(true, false)
      require("ui.buffers").focus(empty)
      main = vim.api.nvim_get_current_win()
    end
    s.source, s.base_options = main, {}
    for _, name in ipairs(options) do s.base_options[name] = vim.wo[main][name] end
    s.win = vim.api.nvim_open_win(buf, false, { split = "below", win = main, height = height(s) })
    -- Span every editor column, then restore sidebars outside the drawer.
    vim.api.nvim_win_call(s.win, function() vim.cmd "wincmd J" end)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(s.tab)) do
      local placement = vim.w[win].dotted_explorer_side
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" and placement ~= "K" and placement ~= "J" then
        local width = vim.api.nvim_win_get_width(win)
        local side = placement or (vim.api.nvim_win_get_position(win)[2] == 0 and "H" or "L")
        vim.api.nvim_win_call(win, function() vim.cmd("wincmd " .. side) end)
        vim.api.nvim_win_set_width(win, width)
      end
    end
    vim.api.nvim_win_set_height(s.win, height(s))
  else
    save_view(s)
    if s.buf ~= buf then vim.api.nvim_win_set_buf(s.win, buf) end
  end
  s.buf, s.ready = buf, false
  configure(s)
  configure_strip(s)
  local view = s.views[buf]
  if view then vim.api.nvim_win_call(s.win, function() vim.fn.winrestview(view) end) end
  s.ready = true
  if focus ~= false then vim.api.nvim_set_current_win(s.win) end
  vim.cmd.redrawstatus()
end

function M.show(name)
  if not require("config.ui").tools.enabled then return end
  local s = state()
  name = name or s.selected
  assert(vim.tbl_contains(tabs, name), "Unknown tool: " .. tostring(name))
  local main = source(s)
  if main then s.source = main end
  local was_minimized = s.minimized
  local buf
  if name == "Terminal" then
    buf = s.terminal
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      buf = require("util.terminal").acquire("tools-" .. s.tab)
      s.terminal = buf
      s.terminals = s.terminals or {}
      table.insert(s.terminals, buf)
    end
  elseif name == "Output" then
    buf = require("ui.output").buffer() or placeholder(s, name, {
      " No task output yet.", " Space r runs the current file into Output.",
      " :OverseerRun selects a project task. List chooses an existing task.",
    })
  elseif name == "Problems" then
    buf = require("ui.problems").buffer(s)
  else
    require "dap"
    buf = require("dapui").elements.console.buffer()
    if not require("dap").session() and vim.bo[buf].buftype ~= "terminal" then
      buf = placeholder(s, name, { " No active debug session. Space d c starts one.",
        " This tab shows the program console (including stdin).", " Scopes opens the existing debugger; REPL opens expression evaluation." })
    end
  end
  s.selected, s.minimized = name, false
  mount(s, buf)
  if was_minimized then vim.api.nvim_win_set_height(s.win, height(s)) end
end

function M.refresh_debug()
  local s = state()
  if s.selected == "Debug" and owns(s) then mount(s, require("dapui").elements.console.buffer(), false) end
end
function M.prepare_output_restart()
  local s = state()
  if s.selected ~= "Output" or not owns(s) then return false end
  mount(s, placeholder(s, "Restart", { " Restarting task…" }), false)
  return true
end
function M.hide()
  local s = state()
  if not owns(s) then detach(s); return end
  save_view(s)
  if not s.minimized then s.height = vim.api.nvim_win_get_height(s.win) end
  local win, focused = s.win, vim.api.nvim_get_current_win() == s.win or vim.api.nvim_get_current_win() == s.strip
  close_strip(s)
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    detach(s)
    vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
  else
    s.win, s.buf, s.ready = nil, nil, false
    vim.api.nvim_win_close(win, true)
  end
  local main = source(s)
  if focused and main then vim.api.nvim_set_current_win(main) end
  vim.cmd.redrawstatus()
end
function M.toggle() if M.is_open() then M.hide() else M.show() end end
function M.minimize()
  local s = state()
  if not owns(s) then return end
  if not s.minimized then s.height = vim.api.nvim_win_get_height(s.win) end
  s.minimized = not s.minimized
  vim.api.nvim_win_set_height(s.win, height(s))
  vim.cmd.redrawstatus()
end
function M.cycle(direction)
  M.show(tabs[(vim.fn.index(tabs, state().selected) + direction) % #tabs + 1])
end
function M.new_terminal()
  local s = state()
  s.terminal = require("util.terminal").acquire("tools-" .. s.tab, true)
  s.terminals = s.terminals or {}
  table.insert(s.terminals, s.terminal)
  M.show("Terminal")
end
function M.cycle_terminal(direction)
  local s = state()
  local live = {}
  for _, buf in ipairs(s.terminals or {}) do
    if vim.api.nvim_buf_is_valid(buf) then live[#live + 1] = buf end
  end
  s.terminals = live
  if #live == 0 then return M.new_terminal() end
  s.terminal = live[(math.max(0, vim.fn.index(live, s.terminal)) + direction) % #live + 1]
  M.show("Terminal")
end
function M.choose()
  local s = state()
  if s.selected == "Output" then return require("ui.output").pick() end
  if s.selected == "Debug" then return require("ui.dap").open() end
  if s.selected == "Problems" then return end
  local items = {}
  for _, buf in ipairs(require("util.terminal").list()) do
    items[#items + 1] = { label = vim.api.nvim_buf_get_name(buf), action = function(menu)
      menu:close(); s.terminal = buf
      s.terminals = s.terminals or {}
      if not vim.tbl_contains(s.terminals, buf) then table.insert(s.terminals, buf) end
      M.show("Terminal")
    end }
  end
  return require("ui.menu").open { title = "Terminals", items = items }
end

local function button(id, label, active, win)
  local group = require("ui.statusline_hover").tool_button(win, id) and "DottedToolHover" or active and "DottedToolActive" or "DottedToolInactive"
  return ("%%#%s#%%%d@v:lua.DottedToolClick@ %s %%X%%#%s#"):format(group, id, label, "DottedToolPadInactive")
end
function M.header()
  local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
  local tab = valid(win) and vim.api.nvim_win_get_tabpage(win) or vim.api.nvim_get_current_tabpage()
  local s, result = states[tab] or state(), {}
  local ids = {}
  local function add(id, label, active)
    ids[#ids + 1] = id
    result[#result + 1] = button(id, label, active, win)
  end
  local width = valid(s.win) and vim.api.nvim_win_get_width(s.win) or vim.o.columns
  local labels = width < 45 and { "D", "O", "P", "T" } or width < 100 and { "Dbg", "Out", "Problems", "Term" } or tabs
  for i, label in ipairs(labels) do add(i, label, s.selected == tabs[i]) end
  result[#result + 1] = "%="
  if width >= 80 then
    if s.selected == "Debug" then add(14, "󰆧"); add(15, "󰆍"); add(16, "□")
    elseif s.selected == "Output" then add(12, "󰋚"); add(13, "󰐕"); add(17, "□"); add(18, "↻")
    elseif s.selected == "Terminal" then add(12, "󰋚"); add(11, "+") end
  end
  add(9, s.minimized and "▴" or "−"); add(10, "×")
  header_targets[win] = ids
  return table.concat(result)
end
function M.highlights()
  vim.api.nvim_set_hl(0, "DottedToolActive", { link = "DottedSt_NormalMode" })
  vim.api.nvim_set_hl(0, "DottedToolInactive", { link = "DottedSt_file" })
  vim.api.nvim_set_hl(0, "DottedToolHover", { link = "DottedBreadcrumbSelection" })
  vim.api.nvim_set_hl(0, "DottedToolPadActive", { link = "DottedToolActive" })
  vim.api.nvim_set_hl(0, "DottedToolPadInactive", { link = "DottedToolInactive" })
end
function M.setup()
  _G.DottedToolsToggle = function()
    local tab = vim.api.nvim_get_current_tabpage()
    vim.schedule(function() if vim.api.nvim_get_current_tabpage() == tab then M.toggle() end end)
  end
  _G.DottedToolClick = function(id)
    local s = state()
    local tab, win = s.tab, s.win
    vim.schedule(function()
      if vim.api.nvim_get_current_tabpage() ~= tab or s.win ~= win or not owns(s) then return end
      if id > 100 and s.terminals and s.terminals[id - 100] then s.terminal = s.terminals[id - 100]; M.show("Terminal")
      elseif tabs[id] then M.show(tabs[id])
      elseif id == 9 then M.minimize() elseif id == 10 then M.hide()
      elseif id == 11 then M.new_terminal() elseif id == 12 then M.choose()
      elseif id == 13 then vim.cmd "OverseerRun"
      elseif id == 14 then require("ui.dap").open()
      elseif id == 15 then require("dap").repl.open()
      elseif id == 16 then require("dap").terminate()
      elseif id == 17 then require("ui.output").stop() elseif id == 18 then require("ui.output").restart() end
    end)
  end
  local group = vim.api.nvim_create_augroup("DottedTools", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = M.highlights })
  vim.api.nvim_create_autocmd("TabClosed", { group = group, callback = function()
    for tab, s in pairs(states) do if not vim.api.nvim_tabpage_is_valid(tab) then states[tab] = nil end end
  end })
  vim.api.nvim_create_autocmd("WinClosed", { group = group, callback = function(args)
    header_targets[tonumber(args.match)] = nil
    for _, s in pairs(states) do if s.win == tonumber(args.match) then
      s.win, s.buf, s.ready = nil, nil, false
      vim.schedule(function() close_strip(s) end)
    end end
  end })
  local queued = false
  vim.api.nvim_create_autocmd("DiagnosticChanged", { group = group, callback = function()
    if queued then return end
    queued = true
    vim.schedule(function()
      queued = false
      for _, s in pairs(states) do if s.selected == "Problems" and owns(s) then require("ui.problems").refresh(s) end end
    end)
  end })
  vim.api.nvim_create_autocmd("VimResized", { group = group, callback = function()
    for _, s in pairs(states) do
      if owns(s) then vim.api.nvim_win_set_height(s.win, math.min(vim.api.nvim_win_get_height(s.win), math.max(2, math.floor(vim.o.lines * 0.6)))) end
    end
  end })
  vim.api.nvim_create_user_command("Tools", function(args)
    if args.args == "" then M.toggle() else M.show(args.args) end
  end, { nargs = "?", complete = function() return tabs end, desc = "Toggle bottom tools or select a tool" })
  M.highlights()
end
return M
