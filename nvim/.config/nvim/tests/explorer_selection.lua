-- Real tree rendering/input: follow the editor while keeping navigation caret-free.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local directory = vim.fn.tempname() .. " explorer selection"
vim.fn.mkdir(directory .. "/nested", "p")
directory = vim.uv.fs_realpath(directory)
vim.fn.writefile({ "alpha" }, directory .. "/alpha.txt")
vim.fn.writefile({ "current" }, directory .. "/nested/current.txt")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", directory .. "/nested/current.txt" }, { rpc = true })
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message, args)
  assert(vim.wait(3000, function() return lua(code, args) == true end, 20), message .. "\n" .. lua("return vim.fn.execute('messages')"))
end
local function selected(path)
  wait([[
    local node = require('nvim-tree.api').tree.get_node_under_cursor()
    return node and node.absolute_path == ...
  ]], "Tree did not select " .. path, { path })
end
local function row(label)
  return lua([[
    local buf = vim.api.nvim_win_get_buf(ExplorerTest.tree)
    for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      if line:find(..., 1, true) then return row end
    end
  ]], { label })
end
local function active_at(line)
  assert(lua([[
    local mark = vim.api.nvim_buf_get_extmark_by_id(vim.api.nvim_win_get_buf(ExplorerTest.tree),
      vim.api.nvim_get_namespaces().DottedExplorerSelection, 1, { details = true })
    return mark[1] == ... - 1 and mark[3].line_hl_group == 'DottedExplorerActive'
  ]], { line }), "Current editor file lost its persistent row highlight")
end
local function hover(line)
  local position = lua([[
    vim.cmd.redraw()
    local pos = vim.fn.screenpos(ExplorerTest.tree, ..., 1)
    local col = vim.api.nvim_win_get_position(ExplorerTest.tree)[2] + vim.api.nvim_win_get_width(ExplorerTest.tree) - 2
    return { pos.row - 1, col }
  ]], { line })
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, position[1], position[2])
  wait([[
    local h = require('ui.statusline_hover').current()
    return h and h.kind == 'widget' and h.win == ExplorerTest.tree and h.id == ...
  ]], "Explorer row did not highlight on hover", { line })
end
local ok, err = xpcall(function()
  vim.rpcrequest(channel, "nvim_ui_attach", 140, 38, { rgb = true })
  wait("return vim.bo.filetype=='text'", "Editor did not start")
  lua([[
    _G.ExplorerTest = { source = vim.api.nvim_get_current_win(), cursor = vim.o.guicursor }
    -- File watching is unrelated to selection and can exceed sandbox limits.
    require('configs.nvimtree').filesystem_watchers = { enable = false }
    require('lazy').load { plugins = { 'nvim-tree.lua' } }
    require('nvim-tree.api').tree.open { path = ... }
    ExplorerTest.tree = require('nvim-tree.api').tree.winid()
  ]], { directory })
  selected(directory .. "/nested/current.txt")
  assert(lua("return vim.o.guicursor:find('DottedExplorerCursor', 1, true) ~= nil"), "Explorer still shows the editor caret")
  assert(lua("return vim.wo.cursorline and vim.wo.cursorlineopt == 'line'"), "Explorer selection is not a full row")
  local current, alpha = row("current.txt"), row("alpha.txt")
  active_at(current)
  vim.rpcrequest(channel, "nvim_input", "<Down>")
  wait("return vim.api.nvim_win_get_cursor(ExplorerTest.tree)[1] == ...", "Arrow navigation did not select the next row", { alpha })
  active_at(current)
  assert(lua("return vim.o.guicursor:find('DottedExplorerCursor', 1, true) ~= nil"), "Keyboard navigation restored the tree caret")
  vim.rpcrequest(channel, "nvim_input", "<Up>")
  selected(directory .. "/nested/current.txt")
  lua("vim.api.nvim_set_current_win(ExplorerTest.source)")
  assert(lua("return vim.o.guicursor == ExplorerTest.cursor"), "Tree caret hiding leaked into the editor")
  hover(alpha)
  active_at(current)
  selected(directory .. "/nested/current.txt")
  assert(lua("return vim.api.nvim_get_current_win() == ExplorerTest.source"), "Hover stole editor focus")
  assert(lua([[
    vim.cmd.redraw()
    local col = vim.api.nvim_win_get_position(ExplorerTest.tree)[2] + vim.api.nvim_win_get_width(ExplorerTest.tree) - 1
    local current, alpha = ...
    local folder = vim.fn.screenpos(ExplorerTest.tree, 1, 1).row
    return vim.fn.screenattr(vim.fn.screenpos(ExplorerTest.tree, current, 1).row, col) ~= vim.fn.screenattr(folder, col)
      and vim.fn.screenattr(vim.fn.screenpos(ExplorerTest.tree, alpha, 1).row, col) ~= vim.fn.screenattr(folder, col)
  ]], { current, alpha }), "Active-file/hover highlights did not fill the row padding")
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, 5, 80)
  wait("return require('ui.statusline_hover').current() == nil", "Explorer hover did not clear over the editor")
  active_at(current)
  assert(lua([[
    return #vim.api.nvim_buf_get_extmark_by_id(vim.api.nvim_win_get_buf(ExplorerTest.tree),
      vim.api.nvim_get_namespaces().DottedExplorerSelection, 2, {}) == 0
  ]]), "Hover left a stale row highlight")
  lua("vim.cmd.edit(vim.fn.fnameescape(...))", { directory .. "/alpha.txt" })
  selected(directory .. "/alpha.txt")
  active_at(row("alpha.txt"))
  -- Entering an already open split must follow that split's file as well.
  lua("vim.cmd.vsplit(vim.fn.fnameescape(...)); ExplorerTest.other = vim.api.nvim_get_current_win()", { directory .. "/nested/current.txt" })
  selected(directory .. "/nested/current.txt")
  lua("vim.api.nvim_set_current_win(ExplorerTest.source)")
  selected(directory .. "/alpha.txt")
  lua("vim.api.nvim_set_current_win(ExplorerTest.tree); require('ui.explorer').action(6)")
  lua("vim.api.nvim_set_current_win(ExplorerTest.other)")
  active_at(row("current.txt"))
  selected(directory .. "/alpha.txt")
  lua("vim.api.nvim_set_current_win(ExplorerTest.tree); require('ui.explorer').action(6)")
  selected(directory .. "/nested/current.txt")
  -- Hover plus Enter selects the hovered row without a block caret.
  hover(row("alpha.txt"))
  vim.rpcrequest(channel, "nvim_input", "<CR>")
  wait("return vim.bo.filetype == 'text' and vim.api.nvim_buf_get_name(0) == ...", "Enter did not open the hovered file", { directory .. "/alpha.txt" })
  assert(lua("return vim.o.guicursor == ExplorerTest.cursor"), "Opening a tree item left the editor caret hidden")
  lua("vim.api.nvim_set_current_win(ExplorerTest.tree); require('ui.explorer').action(5)")
  wait("return vim.bo.filetype == 'dotted_menu' and vim.o.guicursor:find('DottedMenuCursor', 1, true) ~= nil", "Explorer menu did not acquire its cursor")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return vim.bo.filetype == 'NvimTree' and vim.o.guicursor:find('DottedExplorerCursor', 1, true) ~= nil", "Closing a menu did not restore the tree's hidden caret")
  lua("require('ui.tree_search').toggle()")
  wait("return vim.bo.filetype == 'NvimTreeFilter' and vim.api.nvim_get_mode().mode == 'i'", "Explorer search did not open")
  assert(lua("return vim.o.guicursor == ExplorerTest.cursor"), "Explorer search input lost its text caret")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return vim.bo.filetype == 'NvimTree' and vim.o.guicursor:find('DottedExplorerCursor', 1, true) ~= nil", "Closing search did not restore the tree's hidden caret")
  vim.rpcrequest(channel, "nvim_input", ":")
  wait("return vim.api.nvim_get_mode().mode == 'c' and vim.o.guicursor == ExplorerTest.cursor", "Tree caret hiding leaked into the command line")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return vim.o.guicursor:find('DottedExplorerCursor', 1, true) ~= nil", "Leaving the command line restored the tree caret")
  for _, theme in ipairs { "dark", "light", "dotted-onedark", "tokyonight-night", "catppuccin-latte", "vscode-light-modern" } do
    lua([[
      require('config.transparency').enabled = true
      local theme = ...
      if theme == 'dark' or theme == 'light' then
        vim.g.colors_name = nil
        vim.o.background = theme
        vim.cmd.colorscheme('default')
      else assert(require('config.theme_loader').apply(theme, false)) end
    ]], { theme })
    assert(lua([[
      local hl = vim.api.nvim_get_hl
      local line = hl(0, { name = 'CursorLine', link = false })
      return hl(0, { name = 'DottedExplorerCursor', link = false }).blend == 100
        and hl(0, { name = 'DottedExplorerActive', link = false }).bg == line.bg
        and hl(0, { name = 'DottedExplorerSelection', link = false }).bg == line.bg
    ]]), "Theme/transparency change broke the tree's row highlights or hidden caret: " .. lua([[
      return vim.inspect { cursor = vim.api.nvim_get_hl(0, { name = 'DottedExplorerCursor', link = false }),
        active = vim.api.nvim_get_hl(0, { name = 'DottedExplorerActive', link = false }),
        line = vim.api.nvim_get_hl(0, { name = 'CursorLine', link = false }) }
    ]]))
  end
  assert(lua([[
    local overrides = require('config.highlights')
    overrides.groups.CursorLine = { bg = '#123456' }
    overrides.apply()
    for _, name in ipairs { 'CursorLine', 'DottedExplorerSelection', 'DottedExplorerActive' } do
      assert(vim.api.nvim_get_hl(0, { name = name, link = false }).bg == 0x123456,
        name .. ' did not follow the editor line color after a late highlight update')
    end
    overrides.groups.CursorLine = nil
    overrides.apply()
    return true
  ]]), "Explorer did not follow editor line color changes")
  lua("require('nvim-tree.api').tree.reload()")
  active_at(row("alpha.txt"))
  lua("require('nvim-tree.api').tree.close()")
  assert(lua("return vim.o.guicursor == ExplorerTest.cursor"), "Closing the tree left the editor caret hidden")
  lua("vim.cmd.edit(vim.fn.fnameescape(...)); require('nvim-tree.api').tree.open()", { directory .. "/nested/current.txt" })
  lua("ExplorerTest.tree = require('nvim-tree.api').tree.winid()")
  selected(directory .. "/nested/current.txt")
  active_at(row("current.txt"))
  lua([[
    ExplorerTest.first_tab = vim.api.nvim_get_current_tabpage()
    ExplorerTest.first_tree = ExplorerTest.tree
    vim.api.nvim_set_current_win(require('ui.buffers').source_win())
    vim.cmd.tabnew(vim.fn.fnameescape(...))
    require('nvim-tree.api').tree.open()
    ExplorerTest.tree = require('nvim-tree.api').tree.winid()
  ]], { directory .. "/alpha.txt" })
  selected(directory .. "/alpha.txt")
  active_at(row("alpha.txt"))
  lua("vim.cmd.tabclose(); ExplorerTest.tree = ExplorerTest.first_tree; vim.api.nvim_set_current_win(ExplorerTest.tree)")
  selected(directory .. "/nested/current.txt")
  active_at(row("current.txt"))
  lua("vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), { force = true })")
  assert(lua("return vim.o.guicursor == ExplorerTest.cursor"), "Deleting the tree buffer left the editor caret hidden")
  lua("require('nvim-tree.api').tree.open(); vim.o.guicursor = 'a:hor20'; require('nvim-tree.api').tree.close()")
  assert(lua("return vim.o.guicursor == 'a:hor20'"), "Closing the tree overwrote an explicit cursor preference change")
  assert(lua("return vim.v.errmsg == ''"), lua("return vim.fn.execute('messages')"))
end, debug.traceback)
vim.fn.jobstop(channel)
assert(ok, err)
print "Explorer: initial reveal, file/split/tab following, persistent active row, mouse hover and Enter, follow toggle, caret restoration, menus/search/command line, themes/transparency, redraw and reopen passed"
