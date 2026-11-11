-- Real NvimTree + drawer geometry: tab changes must never rebuild the layout.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
vim.o.columns, vim.o.lines = 180, 48
local directory = vim.fn.tempname()
vim.fn.mkdir(directory .. "/sub", "p")
vim.fn.writefile({ "source" }, directory .. "/main.txt")
vim.cmd.edit(vim.fn.fnameescape(directory .. "/main.txt"))
local source, file = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(file, 0, -1, false, { "unsaved source" })
require("lazy").load { plugins = { "nvim-tree.lua" } }
vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(directory))
local tree
for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then tree = win end
end
assert(tree, "NvimTree did not open")
local tree_buf = vim.api.nvim_win_get_buf(tree)
local tree_width, tree_height = vim.api.nvim_win_get_width(tree), vim.api.nvim_win_get_height(tree)
local tools = require "ui.tools"
tools.show("Terminal")
local drawer = tools.current().win
local row = vim.api.nvim_win_get_position(drawer)[1]
local function geometry()
  assert(vim.api.nvim_win_is_valid(tree) and vim.api.nvim_win_get_buf(tree) == tree_buf, "Drawer replaced NvimTree")
  assert(vim.api.nvim_win_get_width(tree) == tree_width, "Drawer resized NvimTree's width")
  assert(vim.api.nvim_win_get_height(tree) == tree_height, "Drawer cut across NvimTree instead of the editor column")
  assert(vim.api.nvim_win_get_position(drawer)[2] > vim.api.nvim_win_get_position(tree)[2], "Drawer overlaps the tree column")
  assert(vim.api.nvim_win_is_valid(source) and vim.api.nvim_win_get_buf(source) == file)
end
geometry()
for _ = 1, 3 do
  for _, name in ipairs { "Output", "Problems", "Debug", "Terminal" } do
    tools.show(name)
    assert(vim.wait(2000, tools.is_open, 10), "Drawer didn't become ready")
    assert(tools.current().win == drawer, "Switching " .. name .. " rebuilt the drawer window")
    assert(vim.api.nvim_win_get_position(drawer)[1] == row, "Tab switch moved the header")
    geometry()
  end
end
-- Calls originating from the explorer still act on the existing editor drawer.
vim.api.nvim_set_current_win(tree)
tools.show("Problems")
assert(tools.current().win == drawer)
geometry()
local ns = vim.api.nvim_create_namespace "dotted-layout-problems"
vim.diagnostic.set(ns, file, { { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "LAYOUT_DIAGNOSTIC" } })
assert(vim.wait(2000, function()
  return table.concat(vim.api.nvim_buf_get_lines(tools.current().buf, 0, -1, false), "\n"):find("LAYOUT_DIAGNOSTIC", 1, true)
end, 10), "Live Problems didn't update")
for i, line in ipairs(vim.api.nvim_buf_get_lines(tools.current().buf, 0, -1, false)) do
  if line:find("LAYOUT_DIAGNOSTIC", 1, true) then vim.api.nvim_win_set_cursor(drawer, { i, 0 }); break end
end
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "xt", false)
assert(vim.api.nvim_get_current_win() == source, "Problem jump went into NvimTree/the drawer")
-- The last active editor, not the first split or the explorer, is the target.
local other_buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(other_buf, 0, -1, false, { "other unsaved source" })
local other = vim.api.nvim_open_win(other_buf, true, { split = "right", win = source })
vim.api.nvim_set_current_win(tree)
tools.show("Problems")
assert(tools.current().source == other, "Drawer forgot the last active editor")
for i, line in ipairs(vim.api.nvim_buf_get_lines(tools.current().buf, 0, -1, false)) do
  if line:find("LAYOUT_DIAGNOSTIC", 1, true) then vim.api.nvim_win_set_cursor(drawer, { i, 0 }); break end
end
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "xt", false)
assert(vim.api.nvim_get_current_win() == other and vim.bo[other_buf].modified, "Jump replaced the wrong split or discarded its previous buffer")
vim.api.nvim_win_close(other, true)
vim.api.nvim_set_current_win(source)
tools.show("Terminal")
vim.cmd "NvimTreeClose"
assert(tools.current().win == drawer and vim.api.nvim_win_is_valid(drawer))
vim.cmd("NvimTreeOpen " .. vim.fn.fnameescape(directory))
assert(tools.current().win == drawer and vim.api.nvim_win_is_valid(drawer))
-- A different Neovim tabpage owns a different drawer and never adopts this one.
local tab = vim.api.nvim_get_current_tabpage()
vim.cmd "tabnew"
assert(vim.wo.winbar == "" and vim.wo.number and vim.wo.winhighlight == "", "New editor tab inherited utility options: " .. vim.inspect {
  ft = vim.bo.filetype, bt = vim.bo.buftype, winbar = vim.wo.winbar, number = vim.wo.number, winhighlight = vim.wo.winhighlight,
})
tools.show("Output")
assert(tools.current().win ~= drawer)
tools.hide()
vim.cmd "tabclose"
assert(vim.api.nvim_get_current_tabpage() == tab and tools.current().win == drawer)
vim.api.nvim_set_current_win(drawer)
vim.cmd "tabnew"
assert(vim.wo.winbar == "" and vim.wo.number and vim.wo.winhighlight == "", "Tab created directly from the drawer inherited its options")
vim.cmd "tabclose"
-- If the editor was closed while the tree and tools remain, a buffer jump must
-- recreate an editor, not put file text or another toolbar into the sidebar.
vim.api.nvim_win_close(source, true)
require("ui.buffers").focus(file)
source = vim.api.nvim_get_current_win()
assert(not vim.w[source].dotted_tool and vim.wo[source].winbar == "" and vim.wo[source].number,
  vim.inspect { win = source, marker = vim.w[source].dotted_tool, winbar = vim.wo[source].winbar, number = vim.wo[source].number, global_number = vim.go.number, ft = vim.bo.filetype })
assert(tools.current().win == drawer and vim.api.nvim_win_is_valid(drawer))
tools.hide()
assert(vim.bo[file].modified and vim.api.nvim_win_get_buf(source) == file)
-- Normal editor preferences must not be mistaken for leaked utility styling.
vim.wo[source].number, vim.wo[source].wrap = false, true
vim.wo[source].winbar, vim.wo[source].winhighlight = "User editor bar", "Normal:Normal"
tools.show("Problems")
tools.hide()
assert(not vim.wo[source].number and vim.wo[source].wrap and vim.wo[source].winbar == "User editor bar"
  and vim.wo[source].winhighlight == "Normal:Normal", "Drawer changed user editor options")
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Drawer layout: persistent window/header, NvimTree width/full height, rapid tab changes, explorer focus and diagnostic jumps passed"
