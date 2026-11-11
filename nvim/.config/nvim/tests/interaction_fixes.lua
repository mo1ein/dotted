-- Real mouse and keyboard regressions for the second feats.md report.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir .. "/nested/deep", "p")
vim.fn.writefile({ "cat cat" }, dir .. "/left.txt")
vim.fn.writefile({ "cat cat" }, dir .. "/right.txt")
vim.fn.writefile({ "import time", "while True:", "    print('HEARTBEAT', flush=True)", "    time.sleep(0.03)" }, dir .. "/run.py")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", dir .. "/left.txt" }, { rpc = true })
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message)
  assert(vim.wait(8000, function() return lua(code) == true end, 20), message .. "\n" .. lua("return vim.inspect {messages=vim.fn.execute('messages'),replace=ReviewReplace and ReviewReplace.options,mouse=vim.fn.getmousepos(),mode=vim.api.nvim_get_mode()} "))
end
local function input(keys) vim.rpcrequest(channel, "nvim_input", keys) end
local function mouse(row, col, button)
  vim.rpcrequest(channel, "nvim_input_mouse", button or "left", "press", "", 0, row, col)
  vim.rpcrequest(channel, "nvim_input_mouse", button or "left", "release", "", 0, row, col)
end
local function control(kind, id, win, hover)
  local pos = lua([[
    local kind,id,win=...
    vim.cmd.redraw()
    local bar=win and vim.wo[win].winbar or vim.o.tabline
    local p=win and vim.api.nvim_win_get_position(win) or {0,0}
    local eval=vim.api.nvim_eval_statusline(bar,{winid=win or vim.api.nvim_get_current_win(),use_winbar=win~=nil,use_tabline=win==nil,maxwidth=win and vim.api.nvim_win_get_width(win) or vim.o.columns,highlights=true})
    for _,span in ipairs(eval.highlights) do
      if span.group:match('^DottedControl_'..kind..'_'..id..'Hover?$') or span.group=='DottedControl_'..kind..'_'..id or span.group=='DottedControl_'..kind..'_'..id..'Active' then
        return {p[1],p[2]+vim.fn.strdisplaywidth(eval.str:sub(1,span.start))+1}
      end
    end
  ]], { kind, id, win })
  assert(pos, "Missing control " .. kind .. ":" .. id)
  if hover then
    vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, pos[1], pos[2])
    wait(("local h=require('ui.statusline_hover').current();return h and h.kind==%q and h.id==%d"):format(kind,id), "Icon didn't hover")
  else mouse(pos[1], pos[2]) end
end
local ok, err = xpcall(function()
  vim.rpcrequest(channel, "nvim_ui_attach", 180, 50, { rgb = true })
  wait("return vim.bo.filetype=='text'", "Startup failed")
  local source = lua([[
    local dir=...
    local left=vim.api.nvim_get_current_win()
    vim.cmd.vsplit(vim.fn.fnameescape(dir..'/right.txt'))
    return {left=left,right=vim.api.nvim_get_current_win()}
  ]], { dir })
  local replace = lua("local s=require('ui.replace').buffer {search='cat',replacement='dog',start_in_insert=false};_G.ReviewReplace=s;return {win=s.win,origin=s.origin,buf=s.buf}")
  assert(replace.origin == source.right)
  assert(lua("local c=vim.api.nvim_win_get_config(...);return c.relative=='win' and c.win==" .. source.right .. " and c.row==0", { replace.win }), "Replacement isn't anchored to its source split")
  control("replace", 1, replace.win, true)
  control("replace", 1, replace.win)
  wait("return ReviewReplace.options.regex==true", "Regex toggle didn't activate")
  control("replace", 1, replace.win)
  wait("return ReviewReplace.options.regex==false", "Regex toggle did not turn off")
  lua("vim.api.nvim_win_set_cursor(...,{2,0})", { replace.win })
  input("<CR>")
  wait("return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(" .. source.right .. "),0,1,false)[1]=='dog cat'", "Enter in replacement field didn't replace")
  control("replace", 7, replace.win)
  wait("return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(" .. source.right .. "),0,1,false)[1]=='dog dog'", "Mouse Replace All failed")
  assert(lua("return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(" .. source.left .. "),0,1,false)[1]=='cat cat'"), "Replaced the other split")
  control("replace", 9, replace.win)
  wait("return vim.bo.filetype=='text'", "Replace didn't close")
  -- A replacement is an undo entry, and both redo chords execute actual redo.
  input("u")
  wait("return vim.api.nvim_get_current_line()=='dog cat'", "Undo failed")
  input("R")
  wait("return vim.api.nvim_get_current_line()=='dog dog'", "Shift-R redo failed")
  input("u<C-S-z>")
  wait("return vim.api.nvim_get_current_line()=='dog dog'", "Ctrl-Shift-Z redo failed")
  lua("require('lazy').load {plugins={'nvim-tree.lua'}};require('nvim-tree.api').tree.open {path=...}", { dir })
  local tree = lua("return require('nvim-tree.api').tree.winid()")
  for id, name in ipairs { "mouse-file.txt", "mouse-folder" } do
    control("explorer", id, tree)
    wait("return vim.bo.filetype=='dotted_input' and vim.api.nvim_get_mode().mode=='i'", "Create button didn't open floating input")
    local prefix = lua("return vim.api.nvim_get_current_line()")
    input(name .. "<CR>")
    wait("return vim.uv.fs_stat(" .. string.format("%q", prefix .. name) .. ")~=nil", "Create button failed")
  end
  control("explorer", 6, tree)
  wait("return not require('ui.explorer').follow", "Follow button failed")
  control("explorer", 6, tree)
  wait("return require('ui.explorer').follow", "Follow button didn't restore")
  control("explorer", 3, tree, true)
  control("explorer", 3, tree) -- The exact button which used to throw collapse_all=nil.
  control("explorer", 4, tree)
  control("explorer", 5, tree)
  wait("return vim.bo.filetype=='dotted_menu' and vim.api.nvim_get_mode().mode=='n'", "Sort used command-line selection")
  input("j<CR>")
  wait("return require('ui.explorer').sort=='extension'", "Sort selection failed")
  control("explorer", 7, tree)
  wait("return vim.bo.filetype=='dotted_menu'", "Move didn't open a native menu")
  input("j<CR>")
  wait("return require('ui.explorer').side=='L'", "Move right failed")
  input("<C-e>")
  wait("return require('nvim-tree.api').tree.winid()==nil", "Ctrl-E didn't close moved tree")
  input("<C-e>")
  wait("local w=require('nvim-tree.api').tree.winid();return w and vim.api.nvim_win_get_position(w)[2]>0", "Ctrl-E didn't reopen tree on the right")
  input("/")
  wait("return vim.bo.filetype=='NvimTreeFilter' and vim.api.nvim_get_mode().mode=='i'", "/ didn't open explorer filter")
  input("nested<CR>")
  wait("return vim.bo.filetype=='NvimTree'", "Filter didn't exit")
  lua("require('nvim-tree.api').filter.live.clear();require('ui.tools').new_terminal();require('ui.tools').new_terminal()")
  local strips = lua("local s=require('ui.tools').current();return {win=s.win,strip=s.strip,first=s.terminals[1],second=s.terminals[2]}")
  local at = lua([[
    local s=require('ui.tools').current();local p=vim.api.nvim_win_get_position(s.strip)
    return {p[1]+1,p[2]+2}
  ]])
  lua("vim.cmd.startinsert()")
  wait("return vim.api.nvim_get_mode().mode=='t'", "Terminal did not enter input mode")
  mouse(at[1], at[2])
  wait("return require('ui.tools').current().buf==" .. strips.first, "Clicking the first second-row shell tab failed")
  local second_at = lua("local s=require('ui.tools').current();local p=vim.api.nvim_win_get_position(s.strip);return {p[1]+1,p[2]+s.session_spans[2].start+2}")
  mouse(second_at[1], second_at[2])
  wait("return require('ui.tools').current().buf==" .. strips.second, "Clicking the second shell tab failed")
  lua("require('ui.tools').hide();vim.api.nvim_set_current_win(" .. source.left .. ");vim.cmd.edit(vim.fn.fnameescape(...))", { dir .. "/run.py" })
  control("run", 1, nil, true)
  control("run", 1)
  wait("local t=require('ui.output').selected;return t and t:is_running()", "Run icon failed")
  wait("return table.concat(vim.api.nvim_buf_get_lines(require('ui.output').buffer(),0,-1,false),''):find('HEARTBEAT',1,true)~=nil", "Process output didn't arrive")
  control("run", 3)
  wait("return require('ui.output').paused==true", "Pause icon didn't pause the process")
  control("run", 3)
  wait("return require('ui.output').paused==false", "Resume icon didn't resume")
  local job = lua("return require('ui.output').selected.strategy.job_id")
  control("run", 7)
  wait("local t=require('ui.output').selected;return t:is_running() and t.strategy.job_id~=" .. job, "Restart didn't restart running task")
  control("run", 8)
  wait("return not require('ui.output').selected:is_running()", "Stop icon didn't stop")
  local project = lua([[
    local root=...;vim.fn.mkdir(root,'p');vim.fn.writefile({'before before'},root..'/sample.txt')
    _G.ReviewProject=require('ui.replace').project {root=root,prefills={search='before',replacement='after'}}
    return vim.fn.bufwinid(ReviewProject:get_buf())
  ]], { dir .. "/replace-project" })
  wait("local s=ReviewProject:get_status_info();return s.stats and s.stats.matches==2", "Project preview not ready")
  control("projectreplace", 3, project)
  wait("return DottedProjectReplaceHeader():find('DottedControl_projectreplace_3Active',1,true)~=nil", "Project word toggle failed")
  control("projectreplace", 4, project)
  wait("return vim.fn.readfile(" .. string.format("%q", dir .. "/replace-project/sample.txt") .. ")[1]=='after after'", "Project mouse Apply failed")
  wait("return ReviewProject:get_status_info().status~='progress'", "Project replacement didn't finish")
  control("projectreplace", 6, project)
  wait("return vim.bo.filetype~='grug-far'", "Project mouse Close failed")
  assert(lua("return vim.v.errmsg==''"), lua("return vim.v.errmsg"))
end, debug.traceback)
lua("pcall(function() require('ui.output').stop() end)")
vim.fn.jobstop(channel)
assert(ok, err)
print "Interaction fixes: actual collapse/sort/move, Ctrl-E and /, split-local replace modes/Enter/mouse, undo/redo, second-row shell clicks, and real run/pause/resume/restart/stop passed"
