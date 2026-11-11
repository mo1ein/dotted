-- Reported regressions: independent replace panes, search cancellation and focus.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
for _, name in ipairs { "A", "B", "C" } do
  vim.fn.writefile({ "print('" .. name .. "_BEGIN', flush=True)", "marker = '" .. name .. "'", "print('" .. name .. "_END', flush=True)" }, dir .. "/" .. name .. ".py")
end
vim.fn.writefile({ [[{"scripts":{"start":"echo WRONG_PROJECT_TARGET"}}]] }, dir .. "/package.json")
for i = 1, 350 do vim.fn.mkdir(dir .. "/folder" .. i, "p") end
vim.fn.writefile({ "deep result" }, dir .. "/folder350/last-target.txt")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", dir .. "/A.py" }, { rpc = true })
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message)
  assert(vim.wait(15000, function() return lua(code) == true end, 20), message .. "\n" .. lua("local o=package.loaded['ui.output'];local t=o and o.selected;return vim.inspect {messages=vim.fn.execute('messages'),cmd=t and t.cmd,output=t and t:get_bufnr() and vim.api.nvim_buf_get_lines(t:get_bufnr(),0,-1,false)}"))
end
local function input(keys) vim.rpcrequest(channel, "nvim_input", keys) end
local function click(kind, id, win)
  local pos = lua([[
    local kind,id,win=...;vim.cmd.redraw()
    local opts={winid=win or vim.api.nvim_get_current_win(),use_winbar=win~=nil,use_tabline=win==nil,maxwidth=win and vim.api.nvim_win_get_width(win) or vim.o.columns,highlights=true}
    local status=vim.api.nvim_eval_statusline(win and vim.wo[win].winbar or vim.o.tabline,opts)
    local p=win and vim.api.nvim_win_get_position(win) or {0,0}
    for _,span in ipairs(status.highlights) do
      local prefix='DottedControl_'..kind..'_'..id
      if span.group==prefix or span.group==prefix..'Active' or span.group==prefix..'Hover' then
        return {p[1],p[2]+vim.fn.strdisplaywidth(status.str:sub(1,span.start))+1}
      end
    end
  ]], { kind, id, win })
  assert(pos, "Missing button " .. kind .. ":" .. id)
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "press", "", 0, pos[1], pos[2])
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "release", "", 0, pos[1], pos[2])
end
local ok, err = xpcall(function()
  vim.rpcrequest(channel, "nvim_ui_attach", 180, 50, { rgb = true })
  wait("return vim.bo.filetype=='python'", "Startup failed")
  local panes = lua([[
    local dir=...;_G.Ownership={left=vim.api.nvim_get_current_win()}
    vim.cmd.vsplit(vim.fn.fnameescape(dir..'/B.py'));Ownership.right=vim.api.nvim_get_current_win()
    return Ownership
  ]], { dir })
  lua("vim.api.nvim_set_current_win(Ownership.left)")
  input("<C-r>")
  wait("return vim.bo.filetype=='dotted-replace'", "Ctrl-R didn't open current-file replace")
  local left = lua("local s=require('ui.replace').current();_G.LeftReplace=s;return s.win")
  lua("vim.api.nvim_buf_set_lines(LeftReplace.buf,0,-1,false,{'marker','left_value'});LeftReplace.refresh();vim.cmd.stopinsert();vim.api.nvim_set_current_win(Ownership.right)")
  input("<C-r>")
  wait("return vim.bo.filetype=='dotted-replace' and require('ui.replace').current().origin==Ownership.right", "Second widget didn't open")
  local right = lua("_G.RightReplace=require('ui.replace').current();vim.api.nvim_buf_set_lines(RightReplace.buf,0,-1,false,{'marker','right_value'});RightReplace.refresh();return RightReplace.win")
  assert(left ~= right and lua("return vim.api.nvim_win_is_valid(LeftReplace.win) and vim.api.nvim_win_is_valid(RightReplace.win)"), "Second widget moved/closed the first")
  click("replace", 1, left)
  wait("return LeftReplace.options.regex and not RightReplace.options.regex", "Mouse option affected the wrong widget")
  click("replace", 7, left)
  wait("return vim.api.nvim_buf_get_lines(LeftReplace.target,1,2,false)[1]:find('left_value',1,true)~=nil", "Left apply edited wrong source")
  click("replace", 7, right)
  wait("return vim.api.nvim_buf_get_lines(RightReplace.target,1,2,false)[1]:find('right_value',1,true)~=nil", "Right apply edited wrong source")
  assert(lua("return require('util.run').capture().win==Ownership.right"), "Focused widget lost its source for Run")
  lua("vim.api.nvim_set_current_win(Ownership.left);vim.cmd.tabnew(vim.fn.fnameescape(...));_G.ThirdReplace=require('ui.replace').buffer {search='marker',replacement='third',start_in_insert=false}", { dir .. "/C.py" })
  assert(lua("return vim.api.nvim_win_is_valid(LeftReplace.win) and vim.api.nvim_win_is_valid(RightReplace.win)"), "Other Neovim tab lost widgets")
  lua("require('ui.replace').close(ThirdReplace);vim.cmd.tabclose();require('ui.replace').close(LeftReplace)")
  assert(lua("return vim.api.nvim_win_is_valid(RightReplace.win) and not RightReplace.timer:is_closing()"), "Closing one widget closed another")
  lua("require('ui.replace').close(RightReplace);vim.api.nvim_set_current_win(Ownership.right)")
  -- Primary Run ignores project metadata and always executes the focused file.
  click("run", 1)
  wait("local t=require('ui.output').selected;return t and t:is_complete() and table.concat(vim.api.nvim_buf_get_lines(t:get_bufnr(),0,-1,false),''):find('B_END',1,true)~=nil", "Run selected the project/other tab or output did not arrive")
  lua("require('ui.tools').hide();vim.api.nvim_set_current_win(Ownership.left);DottedRunControlClick(1);vim.api.nvim_set_current_win(Ownership.right)")
  wait("local t=require('ui.output').selected;return t and t:is_complete() and table.concat(vim.api.nvim_buf_get_lines(t:get_bufnr(),0,-1,false),''):find('A_END',1,true)~=nil", "Queued click lost its focused file")
  lua("require('ui.tools').hide();vim.api.nvim_set_current_win(Ownership.right);require('dap').set_breakpoint(nil,nil,nil);vim.api.nvim_win_set_cursor(Ownership.right,{2,0});require('dap').toggle_breakpoint()")
  click("run", 9)
  wait("local s=require('dap').session();return s and s.stopped_thread_id~=nil", "Debug icon didn't start debugpy")
  assert(lua("local s=require('dap').session();return s.config.program:find('B.py',1,true)~=nil and require('ui.run_toolbar').mode=='debug'"), "Debugger targeted wrong file")
  local previous = lua("vim.api.nvim_set_current_win(Ownership.left);return require('ui.output').selected.id")
  click("run", 1)
  wait("local t=require('ui.output').selected;return t and t.id~=" .. previous .. " and t:is_complete() and require('ui.run_toolbar').mode=='run'", "Run didn't select normal run mode")
  assert(lua("return require('dap').session().stopped_thread_id~=nil"), "Run unexpectedly resumed debugger")
  lua("require('dap').terminate()")
  wait("return require('dap').session()==nil", "Debug cleanup failed")
  lua("require('ui.tools').hide();require('lazy').load {plugins={'nvim-tree.lua'}};require('nvim-tree.api').tree.open {path=...}", { dir })
  local tree = lua("return require('nvim-tree.api').tree.winid()")
  click("explorer", 5, tree)
  wait("return vim.bo.filetype=='dotted_menu'", "Sort menu missing")
  assert(lua("local a=require('ui.controls').anchor('explorer',5,...);local c=vim.api.nvim_win_get_config(0);return c.row==a.row+1 and math.abs(c.col-a.col)<2", { tree }), "Dropdown isn't anchored beside button")
  input("<Esc>")
  click("explorer", 8, tree)
  wait("return require('ui.tree_search').is_open() and vim.api.nvim_get_mode().mode=='i'", "Search didn't open")
  input("last-target")
  wait("local s=require('ui.tree_search').current();return s and not s.scanning and #s.items==1 and s.items[1].relative=='folder350/last-target.txt'", "Search hit the 300-folder limit")
  click("explorer", 8, tree)
  wait("return not require('ui.tree_search').is_open()", "Search button didn't toggle off")
  lua("for _=1,15 do require('ui.explorer').action(8);require('ui.explorer').action(8) end")
  assert(lua("return not require('ui.tree_search').is_open()"), "Rapid toggle left search open")
  assert(lua("return not vim.fn.execute('messages'):find('expansion iteration',1,true) and vim.v.errmsg==''"), lua("return vim.fn.execute('messages')"))
end, debug.traceback)
pcall(lua,"pcall(function() require('dap').terminate() end);pcall(function() require('ui.output').stop() end)")
vim.fn.jobstop(channel)
assert(ok, err)
print "Ownership: independent replace widgets in splits/tabs, focused Run with project metadata and queued clicks, explicit Debug/Run modes, anchored menus, >300 folders and rapid search toggle passed"
