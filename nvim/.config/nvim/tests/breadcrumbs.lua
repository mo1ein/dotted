-- Project-scoped navigation, including cwd inside an enclosing Git repository.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local parent = vim.fn.tempname() .. " breadcrumb parent"
local root = parent .. "/项目 x 100%"
vim.fn.mkdir(parent .. "/.git", "p")
vim.fn.mkdir(root .. "/sub/nested", "p")
vim.fn.writefile({ "outside project" }, parent .. "/OUTSIDE_PROJECT.txt")
vim.fn.writefile({ "inside project" }, root .. "/sub/nested/main.txt")
parent, root = assert(vim.uv.fs_realpath(parent)), assert(vim.uv.fs_realpath(root))
vim.cmd.cd(vim.fn.fnameescape(root))
vim.cmd.edit(vim.fn.fnameescape(root .. "/sub/nested/main.txt"))
local breadcrumbs = require "ui.breadcrumbs"
local source = vim.api.nvim_get_current_win()
local rendered = breadcrumbs.render(vim.api.nvim_get_current_buf(), 500)
assert(rendered:find("项目 x 100%%", 1, true) and not rendered:find("breadcrumb parent", 1, true), "An enclosing Git repo replaced the opened project root")
local menu = breadcrumbs.pick()
local function item(label)
  for i, entry in ipairs(menu.items) do if entry.label:find(label, 1, true) then return i end end
end
local function loaded(label)
  assert(vim.wait(2000, function() return item(label) end, 10), "Menu did not list " .. label)
end
local function key(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
end
loaded("main.txt")
assert(menu.root == root and menu.directory == root .. "/sub/nested", vim.inspect { root = root, menu_root = menu.root, directory = menu.directory })
assert(not vim.api.nvim_win_get_config(menu.win).title, "Path title was not removed")
local file_buf = vim.api.nvim_win_get_buf(source)
key("<Left>")
loaded("nested")
key("<Left>")
loaded("sub")
local root_anchor = vim.deepcopy(menu.anchor)
for _, keys in ipairs { "<Left>", "<BS>", "h", "<Left><Left><BS>" } do
  key(keys)
  assert(menu.directory == root, "Parent navigation escaped the project root")
  assert(not item("OUTSIDE_PROJECT"), "Parent contents leaked into the project dropdown")
end
vim.api.nvim_win_set_cursor(menu.win, { item("sub"), 0 })
key("<Right>")
loaded("nested")
assert(menu.directory == root .. "/sub", "Right did not descend")
assert(menu.anchor.col > root_anchor.col and menu.anchor.row == root_anchor.row, "Right didn't move the menu under the next breadcrumb")
local preview = breadcrumbs.render(file_buf, 500)
assert(preview:find("sub", 1, true) and not preview:find("main.txt", 1, true), "Directory selection was not applied to the breadcrumb")
assert(vim.api.nvim_win_get_buf(source) == file_buf and vim.fn.getcwd() == root, "Directory preview changed the editor or cwd")
assert(not vim.api.nvim_win_get_config(menu.win).title, "Navigation restored the path title")
-- A later cwd change must not move an already-open menu's root boundary.
vim.cmd.cd(vim.fn.fnameescape(parent))
key("<Left><Left><BS>")
loaded("sub")
assert(menu.directory == root and menu.root == root and not item("OUTSIDE_PROJECT"))
menu:close()
assert(vim.api.nvim_get_current_win() == source)
assert(breadcrumbs.render(file_buf, 500):find("main.txt", 1, true), "Dismissing navigation didn't restore the source breadcrumb")

-- `nvim ./x` from the parent directory must respect x, not the parent cwd/repo.
vim.fn.writefile({ "second source" }, root .. "/sub/nested/second.txt")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", "-n", "--cmd", "let g:dotted_ui_test=1", root }, { rpc = true, cwd = parent })
assert(channel > 0)
vim.rpcrequest(channel, "nvim_ui_attach", 180, 44, { rgb = true })
assert(vim.wait(7000, function() return vim.rpcrequest(channel, "nvim_eval", "v:vim_did_enter") == 1 end, 20), "Directory-argument Neovim did not start")
local ok, err = pcall(vim.rpcrequest, channel, "nvim_exec_lua", [[
  local root = ...
  vim.cmd.edit(vim.fn.fnameescape(root .. '/sub/nested/second.txt'))
  local menu = require('ui.breadcrumbs').pick()
  assert(menu.root == root, 'Explicit directory argument did not become the project root: ' .. vim.inspect {expected=root, root=menu.root, argv=vim.fn.argv(), cwd=vim.fn.getcwd(), entered=vim.v.vim_did_enter})
  for _ = 1, 5 do vim.fn.maparg('<Left>', 'n', false, true).callback() end
  assert(menu.directory == root, 'Directory-argument project escaped its root')
  menu:close()
]], { root })
vim.fn.jobstop(channel)
assert(ok, err)
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Breadcrumbs: project root boundaries, applied directory previews, Right/Left menu re-anchoring, source/cwd safety and titleless navigation passed"
