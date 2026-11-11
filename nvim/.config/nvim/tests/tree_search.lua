-- Real search input/results: Enter opens files and search retains tree styling.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local directory = vim.fn.tempname() .. " tree search"
vim.fn.mkdir(directory .. "/nested/sample-folder", "p")
directory = vim.uv.fs_realpath(directory)
-- Make a fresh query span several scan batches before it reaches nested files.
for i = 1, 140 do vim.fn.mkdir(directory .. "/batch" .. i) end
vim.fn.writefile({ "start" }, directory .. "/start.txt")
vim.fn.writefile({ "print('sample')" }, directory .. "/nested/sample.py")
vim.fn.writefile({ "package sample" }, directory .. "/nested/sample.go")
vim.fn.writefile({ "unknown" }, directory .. "/nested/sample.unrecognized_extension")
vim.fn.writefile({ "inside" }, directory .. "/nested/sample-folder/inside.txt")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", directory .. "/start.txt" }, { rpc = true })
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message, args)
  assert(vim.wait(3000, function() return lua(code, args) == true end, 20), message .. "\n" .. lua("return vim.fn.execute('messages')"))
end
local function query(text, enter)
  lua([[
    vim.api.nvim_set_current_win(require('nvim-tree.api').tree.winid())
    require('ui.tree_search').toggle()
  ]])
  wait("return vim.bo.filetype == 'NvimTreeFilter' and vim.api.nvim_get_mode().mode == 'i'", "Search did not open")
  vim.rpcrequest(channel, "nvim_input", text .. (enter and "<CR>" or ""))
  if enter then return end
  wait([[
    local s = require('ui.tree_search').current()
    return s and not s.scanning and vim.api.nvim_buf_get_lines(s.input_buf, 0, 1, false)[1] == ...
  ]], "Search did not finish", { text })
end
local function opened(path)
  wait([[
    return not require('ui.tree_search').is_open() and vim.api.nvim_buf_get_name(0) == ... and vim.bo.buftype == ''
  ]], "Search did not open the selected file in the editor", { directory .. "/" .. path })
  assert(lua("return vim.bo.buflisted"), "Opened search result is missing from editor tabs")
  assert(lua("return vim.o.guicursor == SearchTest.cursor"), "Opening search result hid the editor caret")
end
local function styling()
  assert(lua([[
    local s = require('ui.tree_search').current()
    local lines = vim.api.nvim_buf_get_lines(s.result_buf, 0, -1, false)
    local marks = vim.api.nvim_buf_get_extmarks(s.result_buf, -1, 0, -1, { details = true })
    local source = require('ui.buffers').source_win()
    local current = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(source))
    local function colored(row, start, group)
      for _, mark in ipairs(marks) do
        if mark[2] == row - 1 and mark[3] == start and mark[4].hl_group == group then return true end
      end
      return false
    end
    vim.cmd.redraw()
    for row, item in ipairs(s.items) do
      local name = vim.fs.basename(item.path)
      local icon, highlight
      if item.directory then
        icon, highlight = require('configs.nvimtree').renderer.icons.glyphs.folder.default, 'NvimTreeFolderIcon'
      else
        icon, highlight = require('nvim-web-devicons').get_icon(name, name:match('%.([^%.]+)$'), { default = true })
      end
      assert(lines[row] == icon .. ' ' .. item.relative, 'Search lost the icon for ' .. name)
      assert(colored(row, 0, highlight), 'Search lost the icon color for ' .. name)
      if item.directory then assert(colored(row, #icon + 1, 'NvimTreeFolderName'), 'Search lost folder name colors') end
      if item.path == current then
        local active = false
        for _, mark in ipairs(marks) do
          if mark[2] == row - 1 and mark[4].line_hl_group == 'DottedExplorerActive' then active = true end
        end
        assert(active, 'Search lost the active file highlight')
      end
      if name == 'sample.py' or name == 'sample.go' then
        local glyph, text = vim.fn.screenpos(s.results, row, 1), vim.fn.screenpos(s.results, row, #icon + 2)
        assert(vim.fn.screenattr(glyph.row, glyph.col) ~= vim.fn.screenattr(text.row, text.col), 'File icon color did not render')
      end
    end
    assert(vim.wo[s.results].cursorlineopt == 'line', 'Search selection is not a full row')
    assert(vim.wo[s.results].winhighlight:find('Normal:NvimTreeNormal', 1, true), 'Search lost tree background/text colors')
    assert(vim.wo[s.results].winhighlight:find('CursorLine:DottedExplorerSelection', 1, true), 'Search lost tree selection colors')
    return true
  ]]), "Search icons/colors did not match the tree")
end
local ok, err = xpcall(function()
  vim.rpcrequest(channel, "nvim_ui_attach", 150, 42, { rgb = true })
  wait("return vim.bo.filetype == 'text'", "Editor did not start")
  lua([[
    _G.SearchTest = { source = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf(), cursor = vim.o.guicursor }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved start' })
    require('configs.nvimtree').filesystem_watchers = { enable = false }
    require('lazy').load { plugins = { 'nvim-tree.lua' } }
    require('nvim-tree.api').tree.open { path = ... }
  ]], { directory })
  query("sample.py", true)
  opened("nested/sample.py")
  assert(lua("return vim.api.nvim_get_current_line() == \"print('sample')\""), "Search result did not load file contents")
  assert(lua("return vim.bo[SearchTest.buf].modified and vim.api.nvim_buf_get_lines(SearchTest.buf, 0, 1, false)[1] == 'unsaved start'"), "Opening search result lost unsaved editor text")
  query("sample")
  styling()
  for _, background in ipairs { "light", "dark" } do
    lua("vim.g.colors_name = nil; vim.o.background = ...; vim.cmd.colorscheme('default')", { background })
    styling()
  end
  local position = lua([[
    local s = require('ui.tree_search').current()
    for row, item in ipairs(s.items) do
      if vim.fs.basename(item.path) == 'sample.go' then
        local pos = vim.fn.screenpos(s.results, row, 1)
        return { pos.row - 1, pos.col - 1, row }
      end
    end
  ]])
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, position[1], position[2])
  wait("local s = require('ui.tree_search').current(); return s and s.index == ...", "Search hover did not select a result", { position[3] })
  assert(lua("return vim.bo.filetype == 'NvimTreeFilter'"), "Hover stole focus/opened a search result")
  styling()
  lua("vim.cmd.stopinsert(); vim.api.nvim_set_current_win(require('ui.tree_search').current().results)")
  wait("return vim.api.nvim_get_mode().mode == 'n' and vim.o.guicursor:find('DottedExplorerCursor', 1, true) ~= nil", "Search result list shows a block caret")
  vim.rpcrequest(channel, "nvim_input", "<CR>")
  opened("nested/sample.go")
  query("sample.unrecognized_extension")
  position = lua("local s = require('ui.tree_search').current(); local p = vim.fn.screenpos(s.results, 1, 1); return { p.row - 1, p.col - 1 }")
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "press", "", 0, position[1], position[2])
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "release", "", 0, position[1], position[2])
  opened("nested/sample.unrecognized_extension")
  query("sample-folder", true)
  wait([[
    if vim.bo.filetype ~= 'NvimTree' or require('ui.tree_search').is_open() then return false end
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('inside.txt', 1, true) ~= nil
  ]], "Enter did not reveal/expand the folder result")
  query("no-such-result")
  vim.rpcrequest(channel, "nvim_input", "<CR>")
  assert(lua("local s = require('ui.tree_search').current(); return s and #s.items == 0 and vim.bo.filetype == 'NvimTreeFilter'"), "Enter with no results changed the current file")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return not require('ui.tree_search').is_open()", "Search did not close")
  assert(lua("return vim.v.errmsg == ''"), lua("return vim.fn.execute('messages')"))
end, debug.traceback)
vim.fn.jobstop(channel)
assert(ok, err)
print "Tree search: immediate query+Enter across scan batches, Enter/click opens editor tabs, unsaved text, colored icons, themes, hover, caret restoration, folders and empty results passed"
