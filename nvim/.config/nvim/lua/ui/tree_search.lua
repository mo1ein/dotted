-- Search without expanding NvimTree or sharing its scheduled live-filter state.
local M = {}
local active
local namespace = vim.api.nvim_create_namespace "DottedTreeSearch"
local function valid(win) return win and vim.api.nvim_win_is_valid(win) end
function M.current() return active end
function M.is_open() return active ~= nil and active.tab == vim.api.nvim_get_current_tabpage() end
function M.close()
  local s = active
  if not s then return end
  active, s.serial = nil, s.serial + 1
  local focus = vim.api.nvim_get_current_win() == s.input or vim.api.nvim_get_current_win() == s.results
  if focus then vim.cmd.stopinsert() end
  for _, win in ipairs { s.input, s.results } do if valid(win) then vim.api.nvim_win_close(win, true) end end
  pcall(vim.api.nvim_del_augroup_by_id, s.group)
  if focus and valid(s.tree) then vim.api.nvim_set_current_win(s.tree) end
  vim.cmd.redrawstatus()
end
local function geometry(s)
  local width = math.max(1, vim.api.nvim_win_get_width(s.tree) - 2)
  local height = math.max(1, vim.api.nvim_win_get_height(s.tree) - 5)
  return { relative = "win", win = s.tree, style = "minimal", border = "rounded", row = 1, col = 0,
    width = width, height = 1, title = " Find files/folders ", zindex = 180 },
    { relative = "win", win = s.tree, style = "minimal", border = "none", row = 4, col = 1,
      width = width, height = height, zindex = 180 }
end
local function render(s)
  if active ~= s or not valid(s.results) then return end
  local lines, decorations = {}, {}
  local glyphs = require("configs.nvimtree").renderer.icons.glyphs
  local devicons = package.loaded["nvim-web-devicons"]
  for row, item in ipairs(s.items) do
    local icon, highlight
    if item.directory then icon, highlight = glyphs.folder.default, "NvimTreeFolderIcon"
    elseif devicons then
      local name = vim.fs.basename(item.path)
      icon, highlight = devicons.get_icon(name, name:match("%.([^%.]+)$"), { default = true })
    end
    icon, highlight = icon or glyphs.default, highlight or "NvimTreeNormal"
    lines[row] = icon .. " " .. item.relative
    decorations[#decorations + 1] = { row = row - 1, first = 0, last = #icon, group = highlight }
    if item.directory then
      decorations[#decorations + 1] = { row = row - 1, first = #icon + 1, last = #lines[row], group = "NvimTreeFolderName" }
    end
  end
  if #lines == 0 then lines = { s.scanning and " Searching…" or " No matches" } end
  vim.bo[s.result_buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.result_buf, 0, -1, false, lines)
  vim.bo[s.result_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(s.result_buf, namespace, 0, -1)
  for _, decoration in ipairs(decorations) do
    vim.api.nvim_buf_set_extmark(s.result_buf, namespace, decoration.row, decoration.first, {
      end_row = decoration.row, end_col = decoration.last, hl_group = decoration.group,
    })
  end
  local source = require("ui.buffers").source_win()
  local path = source and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(source))
  path = path and (vim.uv.fs_realpath(path) or path)
  for row, item in ipairs(s.items) do
    if item.path == path then
      vim.api.nvim_buf_set_extmark(s.result_buf, namespace, row - 1, 0, { line_hl_group = "DottedExplorerActive", priority = 80 })
    end
  end
  s.index = math.max(1, math.min(s.index, #s.items))
  if #s.items > 0 then
    vim.api.nvim_buf_set_extmark(s.result_buf, namespace, s.index - 1, 0, { line_hl_group = "DottedExplorerSelection", priority = 90 })
  end
  vim.api.nvim_win_set_cursor(s.results, { s.index, 0 })
  vim.api.nvim_win_set_config(s.input, { footer = (" %d%s results · Enter: open · Esc: close "):format(#s.items, (s.scanning or s.limited) and "+" or ""), footer_pos = "left" })
end
local function search(s, serial)
  if active ~= s or s.serial ~= serial or s.searched_serial == serial then return end
  s.searched_serial = serial
  local query = (vim.api.nvim_buf_get_lines(s.input_buf, 0, 1, false)[1] or ""):lower()
  s.items, s.index, s.scanning, s.limited = {}, 1, true, false
  local queue, next_dir, handle = { s.root }, 1, nil
  local directory
  local function pump()
    if active ~= s or s.serial ~= serial or not valid(s.tree) then return end
    local started = vim.uv.hrtime()
    for _ = 1, 128 do
      if not handle then
        directory = queue[next_dir]
        next_dir = next_dir + 1
        if not directory then s.scanning = false; break end
        handle = vim.uv.fs_scandir(directory)
      end
      local name, kind
      if handle then name, kind = vim.uv.fs_scandir_next(handle) end
      if not name then handle = nil
      elseif name ~= ".git" then
        local path = vim.fs.joinpath(directory, name)
        local relative = vim.fs.relpath(s.root, path)
        if query ~= "" and kind == "directory" then queue[#queue + 1] = path end
        if query == "" or relative:lower():find(query, 1, true) then
          s.items[#s.items + 1] = { path = path, relative = relative, directory = kind == "directory" }
          if #s.items >= 200 then s.scanning = false; s.limited = true; break end
        end
      end
      if vim.uv.hrtime() - started > 4000000 then break end
    end
    render(s)
    if s.scanning then vim.defer_fn(pump, 1) end
    if not s.scanning and s.confirm == serial then
      vim.schedule(function()
        if active == s and s.serial == serial and s.confirm == serial then
          s.confirm = nil
          s.choose()
        end
      end)
    end
  end
  pump()
end
function M.toggle()
  if active then M.close(); return end
  local api = require "nvim-tree.api"
  local tree = api.tree.winid()
  if not valid(tree) then return end
  local root = api.tree.get_nodes().absolute_path or vim.fn.getcwd()
  local s = { tree = tree, tab = vim.api.nvim_get_current_tabpage(), root = root == "/" and root or root:gsub("/$", ""), serial = 0, items = {}, index = 1 }
  active = s
  s.input_buf, s.result_buf = vim.api.nvim_create_buf(false, true), vim.api.nvim_create_buf(false, true)
  for _, buf in ipairs { s.input_buf, s.result_buf } do vim.bo[buf].bufhidden = "wipe" end
  vim.bo[s.input_buf].filetype, vim.bo[s.result_buf].filetype = "NvimTreeFilter", "NvimTreeSearch"
  local input_config, result_config = geometry(s)
  s.results = vim.api.nvim_open_win(s.result_buf, false, result_config)
  s.input = vim.api.nvim_open_win(s.input_buf, true, input_config)
  vim.wo[s.results].cursorline, vim.wo[s.results].wrap = true, false
  vim.wo[s.results].cursorlineopt = "line"
  vim.wo[s.results].winhighlight = "Normal:NvimTreeNormal,NormalNC:NvimTreeNormalNC,EndOfBuffer:NvimTreeEndOfBuffer,CursorLine:DottedExplorerSelection"
  vim.wo[s.input].winhighlight = "Normal:NvimTreeNormal,FloatBorder:FloatBorder"
  local function choose()
    -- Input mappings can run before the scheduled search for the latest text.
    if s.searched_serial ~= s.serial or s.scanning then
      s.confirm = s.serial
      search(s, s.serial)
      return
    end
    local item = s.items[s.index]
    if not item then return end
    M.close()
    api.tree.find_file { buf = item.path, open = false, focus = true }
    if item.directory then api.node.expand(api.tree.get_node_under_cursor())
    else
      local buf = vim.fn.bufadd(item.path)
      vim.bo[buf].buflisted = true
      require("ui.buffers").focus(buf)
    end
  end
  s.choose = choose
  local function move(delta)
    s.index = math.max(1, math.min(#s.items, s.index + delta)); render(s)
  end
  for _, buf in ipairs { s.input_buf, s.result_buf } do
    vim.keymap.set({ "n", "i" }, "<Esc>", M.close, { buffer = buf, nowait = true })
    vim.keymap.set({ "n", "i" }, "<C-f>", M.close, { buffer = buf, nowait = true })
    vim.keymap.set({ "n", "i" }, "<CR>", choose, { buffer = buf })
    vim.keymap.set({ "n", "i" }, "<C-CR>", choose, { buffer = buf })
    for key, direction in pairs { ["<Down>"] = 1, ["<C-n>"] = 1, ["<Up>"] = -1, ["<C-p>"] = -1 } do
      vim.keymap.set({ "n", "i" }, key, function() move(direction) end, { buffer = buf })
    end
    require("ui.controls").attach_winbar(buf, function() return tree end, "explorer", function(id) _G.DottedExplorerClick(id) end)
  end
  vim.keymap.set("n", "j", function() move(1) end, { buffer = s.result_buf })
  vim.keymap.set("n", "k", function() move(-1) end, { buffer = s.result_buf })
  require("ui.statusline_hover").register(s.results, function(mouse)
    if mouse.line >= 1 and mouse.line <= #s.items then s.index = mouse.line; render(s); return mouse.line end
  end, nil, function(mouse)
    if mouse.line >= 1 and mouse.line <= #s.items then s.index = mouse.line; choose() end
  end)
  s.group = vim.api.nvim_create_augroup("DottedTreeSearch", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = s.group, callback = function() render(s) end })
  vim.api.nvim_buf_attach(s.input_buf, false, { on_lines = function()
    s.serial = s.serial + 1
    s.confirm = nil
    local serial = s.serial
    vim.schedule(function() search(s, serial) end)
  end })
  vim.api.nvim_create_autocmd("WinClosed", { group = s.group, callback = function(args)
    local win = tonumber(args.match)
    if win == s.tree or win == s.input or win == s.results then vim.schedule(function() if active == s then M.close() end end) end
  end })
  vim.api.nvim_create_autocmd("TabLeave", { group = s.group, callback = M.close })
  vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, { group = s.group, callback = function()
    if active ~= s or not valid(tree) then return end
    local a, b = geometry(s)
    if valid(s.input) then vim.api.nvim_win_set_config(s.input, a) end
    if valid(s.results) then vim.api.nvim_win_set_config(s.results, b) end
  end })
  search(s, s.serial)
  vim.cmd.startinsert()
  vim.cmd.redrawstatus()
end
return M
