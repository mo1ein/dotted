-- Exercise real input and mouse callbacks, including explorer-local Ctrl-F.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir .. "/nested/needle-folder", "p")
vim.fn.mkdir(dir .. "/unrelated", "p")
vim.fn.writefile({ "print('run')" }, dir .. "/nested/needle.py")
vim.fn.writefile({ "run:", "\t@printf 'PROJECT_UI_RUN_OK\\n'" }, dir .. "/Makefile")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", dir .. "/nested/needle.py" }, { rpc = true })
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message)
  assert(vim.wait(5000, function() return lua(code) == true end, 20), message .. "\n" .. lua("return vim.fn.execute('messages')"))
end
local function click(label)
  local pos = lua([[
    vim.cmd.redraw()
    local line=''
    for col=1,vim.o.columns do line=line..vim.fn.screenstring(1,col) end
    local at=line:find(...,1,true)
    return at and vim.fn.strdisplaywidth(line:sub(1,at-1))
  ]], { label })
  assert(pos, "Missing toolbar control: " .. label)
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "press", "", 0, 0, pos)
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "release", "", 0, 0, pos)
end
local ok, err = xpcall(function()
  vim.rpcrequest(channel, "nvim_ui_attach", 160, 45, { rgb = true })
  wait("return vim.bo.filetype=='python'", "Source did not load")
  lua([[
    _G.RunClicked=nil
    _G.RunFileClicks=0
    package.loaded['util.run_file']=function() _G.RunClicked=vim.bo.filetype; _G.RunFileClicks=RunFileClicks+1 end
    require('lazy').load {plugins={'nvim-tree.lua'}}
    require('nvim-tree.api').tree.open {path=...}
  ]], { dir })
  vim.rpcrequest(channel, "nvim_input", "<C-f>")
  wait("return vim.bo.filetype=='NvimTreeFilter' and vim.api.nvim_get_mode().mode=='i'", "Tree filter did not enter insert mode")
  vim.rpcrequest(channel, "nvim_input", "needle")
  wait("return vim.bo.filetype=='NvimTreeFilter' and vim.api.nvim_get_current_line()=='needle'", "Ctrl-F didn't open tree search")
  wait([[
    local s=require('ui.tree_search').current()
    if not s or s.scanning then return false end
    local text=table.concat(vim.api.nvim_buf_get_lines(s.result_buf,0,-1,false),'\n')
    return text:find('needle.py',1,true) and text:find('needle-folder',1,true) and not text:find('unrelated',1,true)
  ]], "Nested file/folder results missing")
  vim.rpcrequest(channel, "nvim_input", "<CR>")
  wait([[
    local api=require('nvim-tree.api')
    local win=api.tree.winid()
    local text=table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win),0,-1,false),'\n')
    return vim.bo.filetype=='NvimTree' and text:find('needle-folder',1,true) and not require('ui.tree_search').is_open()
  ]], "Live filter didn't include nested files/folders or exclude unrelated entries")
  vim.rpcrequest(channel, "nvim_input", "g/")
  wait([[
    return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('unrelated',1,true)~=nil
  ]], "Clear filter didn't restore the tree")
  click("▶ File")
  wait("return RunClicked=='python'", "Run button didn't target source from explorer")
  click("▶ Project")
  wait([[
    local task=require('ui.output').selected
    return task and task:is_complete() and task.exit_code==0
      and table.concat(vim.api.nvim_buf_get_lines(task:get_bufnr(),0,-1,false),'\n'):find('PROJECT_UI_RUN_OK',1,true)~=nil
  ]], "Project button didn't launch the application from explorer focus")
  assert(lua("return RunFileClicks==1"), "Project button executed the focused file")
  lua("require('config.theme_loader').apply('dotted-onedark',false)")
  click("Light")
  wait("return vim.o.background=='light'", "Light button didn't switch appearance")
  lua("require('ui.tools').show('Terminal')")
  click("Dark")
  wait("return vim.o.background=='dark'", "Dark button didn't work with tools focused")
  assert(lua("return vim.v.errmsg==''"), lua("return vim.v.errmsg"))
end, debug.traceback)
vim.fn.jobstop(channel)
assert(ok, err)
print "Feature TUI: explorer-only Ctrl-F, nested results, separate File/Project mouse controls and light/dark controls passed"
