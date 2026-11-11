-- Real mouse motion across every owned tabline/winbar control. Hover must not
-- run callbacks, change focus, discard text or start/stop tools and processes.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local directory = vim.fn.tempname() .. " hover controls"
vim.fn.mkdir(directory .. "/.git", "p")
vim.fn.writefile({ "alpha" }, directory .. "/alpha.txt")
vim.fn.writefile({ "beta" }, directory .. "/βeta100%.txt")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", "--cmd", "let g:dotted_ui_test=1", directory .. "/alpha.txt" }, { rpc = true })
assert(channel > 0)
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message)
  assert(vim.wait(7000, function() return lua(code) end, 20), message .. "\n" .. lua("return vim.inspect {mouse=vim.fn.getmousepos(),hover=require('ui.statusline_hover').current(),mode=vim.api.nvim_get_mode(),messages=vim.fn.execute('messages') }"))
end
local function position(label, where, occurrence)
  local result = lua([[
    vim.cmd.redraw()
    local label,where,wanted=...
    local seen=0
    local strip=require("ui.tools").current().strip
    local header_row=strip and vim.api.nvim_win_is_valid(strip) and (vim.api.nvim_win_get_position(strip)[1]+1)
    for row=1,vim.o.lines do
      if (where=='top' and row==1) or (where=='header' and row==header_row) or where=='any' then
        local line=''
        for col=1,vim.o.columns do line=line..vim.fn.screenstring(row,col) end
        local from=1
        while true do
          local at=line:find(label,from,true)
          if not at then break end
          seen=seen+1
          if seen==wanted then return {row-1,vim.fn.strdisplaywidth(line:sub(1,at-1))} end
          from=at+#label
        end
      end
    end
  ]], { label, where, occurrence or 1 })
  assert(type(result) == "table" and result[1], "Control not visible: " .. label)
  return result
end
local function hover(label, where, kind, id, occurrence)
  local at = position(label, where, occurrence)
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, at[1], at[2])
  wait(("local h=require('ui.statusline_hover').current();return h and h.kind==%q and h.id==%d"):format(kind, id), "Control didn't hover: " .. label)
end
local function clear()
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, 4, 80)
  wait("return require('ui.statusline_hover').current()==nil", "Hover didn't clear over editor text")
end
local ok, err = xpcall(function()
  vim.rpcrequest(channel, "nvim_ui_attach", 180, 44, { rgb = true })
  wait("return vim.bo.filetype=='text'", "Editor didn't start")
  local files = lua([[
    local dir=...
    local alpha=vim.api.nvim_get_current_buf()
    vim.cmd.edit(vim.fn.fnameescape(dir..'/βeta100%.txt'))
    vim.api.nvim_buf_set_lines(0,0,-1,false,{'unsaved beta'})
    return {alpha=alpha,beta=vim.api.nvim_get_current_buf(),source=vim.api.nvim_get_current_win()}
  ]], { directory })
  lua([[
    _G.HoverCalls=0;_G.HoverOriginal={}
    for _,name in ipairs {'DottedBufferClick','DottedBufferClose','DottedDashboardClick','DottedToolClick'} do
      HoverOriginal[name]=_G[name]
      _G[name]=function() HoverCalls=HoverCalls+1 end
    end
  ]])
  hover("alpha.txt", "top", "buffer", files.alpha)
  hover("[1]", "top", "buffer", files.alpha)
  hover("βeta100%.txt", "top", "buffer", files.beta)
  hover("×", "top", "buffer_close", files.alpha)
  hover("×", "top", "buffer_close", files.beta, 2)
  hover("dotted", "top", "dashboard", 0)
  assert(lua("return vim.api.nvim_get_current_buf()==" .. files.beta .. " and vim.bo.modified"), "Top-tab hover selected/closed a buffer or lost unsaved text")
  assert(lua("return vim.api.nvim_get_hl(0,{name='DottedHoverNumber',link=false}).bold"), "Hovered buffer numbers aren't bold")
  clear()
  local pages = lua([[
    local first=vim.api.nvim_get_current_tabpage()
    vim.cmd.tabnew()
    local second,buf=vim.api.nvim_get_current_tabpage(),vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_tabpage(first)
    return {first=first,second=second,buf=buf}
  ]])
  hover(" 2 ", "top", "tabpage", pages.second)
  assert(lua("return vim.api.nvim_get_current_tabpage()==" .. pages.first), "Hover switched Neovim tabpages")
  lua("vim.cmd('tabclose 2');vim.api.nvim_buf_delete(" .. pages.buf .. ",{force=true})")
  wait("return require('ui.statusline_hover').current()==nil", "Closed tabpage retained hover state")
  lua([[
    local dir=...
    require('lazy').load {plugins={'nvim-tree.lua'}}
    vim.cmd('NvimTreeOpen '..vim.fn.fnameescape(dir))
    require('ui.tools').show('Terminal')
  ]], { directory })
  local drawer = lua("return require('ui.tools').current().win")
  lua("vim.api.nvim_set_current_win(" .. files.source .. ")")
  for id, name in ipairs { "Debug", "Output", "Problems", "Terminal" } do hover(name, "header", "tool_button", id) end
  for _, pair in ipairs { { "󰋚", 12 }, { "+", 11 }, { "−", 9 }, { "×", 10 } } do hover(pair[1], "header", "tool_button", pair[2]) end
  assert(lua("return vim.api.nvim_get_current_win()==" .. files.source .. " and require('ui.tools').current().selected=='Terminal' and require('ui.tools').current().win==" .. drawer), "Header hover changed focus, selected a tool or rebuilt the drawer")
  for _, tool in ipairs { "Output", "Debug" } do
    lua("require('ui.tools').show('" .. tool .. "')")
    local buttons = tool == "Output" and { { "󰋚", 12 }, { "󰐕", 13 }, { "□", 17 }, { "↻", 18 } }
      or { { "󰆧", 14 }, { "󰆍", 15 }, { "□", 16 } }
    for _, pair in ipairs(buttons) do hover(pair[1], "header", "tool_button", pair[2]) end
  end
  lua("require('ui.tools').minimize()")
  hover("▴", "header", "tool_button", 9)
  assert(lua("return require('ui.tools').current().minimized"), "Hover restored the minimized panel without a click")
  lua("require('ui.tools').minimize()")
  assert(lua("return HoverCalls==0"), "Hover executed a clickable control")
  lua("for name,fn in pairs(HoverOriginal) do _G[name]=fn end")
  vim.rpcrequest(channel, "nvim_ui_try_resize", 95, 30)
  hover(" Out ", "header", "tool_button", 2)
  vim.rpcrequest(channel, "nvim_ui_try_resize", 65, 22)
  hover(" O ", "header", "tool_button", 2)
  hover("×", "header", "tool_button", 10)
  vim.rpcrequest(channel, "nvim_ui_try_resize", 180, 44)
  assert(lua("return require('ui.tools').current().win==" .. drawer), "Compact hover rebuilt the drawer")
  clear()
  assert(lua("return vim.bo[" .. files.beta .. "].modified and vim.api.nvim_buf_get_lines(" .. files.beta .. ",0,1,false)[1]=='unsaved beta'"), "Hover discarded unsaved work")
  local problem_row = lua([[
    local buf=...
    local ns=vim.api.nvim_create_namespace('hover-controls-diagnostics')
    vim.diagnostic.set(ns,buf,{
      {lnum=0,col=0,severity=1,message='HOVER_DIAGNOSTIC_ONE'},
      {lnum=0,col=2,severity=2,message='HOVER_DIAGNOSTIC_TWO'},
    })
    require('ui.tools').show('Problems')
    for row,item in pairs(require('ui.tools').current().problem_items) do
      if item.message=='HOVER_DIAGNOSTIC_TWO' then return row end
    end
  ]], { files.beta })
  lua("vim.api.nvim_set_current_win(" .. files.source .. ")")
  local source_cursor = lua("return vim.api.nvim_win_get_cursor(0)")
  hover("HOVER_DIAGNOSTIC_TWO", "any", "widget", problem_row)
  assert(lua("return vim.api.nvim_get_current_win()==" .. files.source .. " and vim.api.nvim_win_get_buf(0)==" .. files.beta), "Problem hover jumped into a file or changed focus")
  assert(vim.deep_equal(source_cursor, lua("return vim.api.nvim_win_get_cursor(0)")), "Problem hover moved the editor cursor")
  clear()
  lua("require('ui.tools').hide()")
  local confirm_cursor = lua([[
    _G.HoverConfirmation=nil
    require('ui.confirm').open('Hover test',function(answer) _G.HoverConfirmation=answer end)
    return vim.api.nvim_win_get_cursor(0)
  ]])
  hover("[ Yes, save ]", "any", "widget", 1)
  assert(lua("return HoverConfirmation==nil"), "Confirmation hover accepted a choice")
  assert(vim.deep_equal(confirm_cursor, lua("return vim.api.nvim_win_get_cursor(0)")), "Confirmation hover changed its safe keyboard default")
  vim.rpcrequest(channel, "nvim_input", "<CR>")
  wait("return HoverConfirmation==false", "Hovering Yes changed Enter from the safe No default")
  lua([[
    _G.HoverPreview=nil;_G.HoverAccepted=nil;_G.HoverCancelled=nil
    require('ui.theme_picker').open({'HOVER_THEME_ALPHA','HOVER_THEME_BETA'},{
      hover=function(name) _G.HoverPreview=name end,
      select=function(name) _G.HoverAccepted=name end,
      finish=function() _G.HoverCancelled=true end,
      stop=function() end,cancel_if_idle=function() end,
    })
  ]])
  hover("HOVER_THEME_BETA", "any", "widget", 2)
  wait("return HoverPreview=='HOVER_THEME_BETA'", "Native picker hover didn't preview its selected row")
  assert(lua("return HoverAccepted==nil and not vim.wo.winhighlight:find('Dotted',1,true)"), "Hover accepted a theme or restyled the picker")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return HoverCancelled==true", "Native picker hover broke cancellation")
  lua("vim.api.nvim_set_current_win(" .. files.source .. ")")
  local dashboard = lua("return require('ui.dashboard').open()")
  local quit_row = lua("for i,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do if line:find('[q]',1,true) then return i end end")
  hover("[q]", "any", "widget", quit_row)
  assert(lua("return vim.bo.filetype=='dashboard'"), "Hover executed dashboard Quit")
  local new_row = lua("for i,line in ipairs(vim.api.nvim_buf_get_lines(0,0,-1,false)) do if line:find('[n]',1,true) then return i end end")
  hover("[n]", "any", "widget", new_row)
  local at = position("[n]", "any")
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "press", "", 0, at[1], at[2])
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "release", "", 0, at[1], at[2])
  wait("return vim.bo.buftype=='' and vim.api.nvim_buf_get_name(0)=='' and vim.api.nvim_get_mode().mode=='i'", "Dashboard button didn't remain clickable after hovering")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  lua("vim.api.nvim_set_current_win(" .. files.source .. ");vim.api.nvim_win_close(" .. dashboard.win .. ",false)")
  assert(lua("return vim.bo[" .. files.beta .. "].modified"), "Widget hover discarded unsaved work")
  hover("alpha.txt", "top", "buffer", files.alpha)
  at = position("alpha.txt", "top")
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "press", "", 0, at[1], at[2])
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "release", "", 0, at[1], at[2])
  wait("return vim.api.nvim_get_current_buf()==" .. files.alpha, "Hovered file caption no longer selects the right buffer")
  hover("×", "top", "buffer_close", files.alpha)
  at = position("×", "top")
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "press", "", 0, at[1], at[2])
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "release", "", 0, at[1], at[2])
  wait("return not vim.api.nvim_buf_is_valid(" .. files.alpha .. ") or not vim.bo[" .. files.alpha .. "].buflisted", "Hovered close button no longer closes the right buffer")
  assert(lua("return vim.bo[" .. files.beta .. "].modified"), "Clicking the hovered close button discarded a different buffer")
  assert(lua("return vim.v.errmsg==''"), lua("return vim.v.errmsg"))
end, debug.traceback)
vim.fn.jobstop(channel)
assert(ok, err)
print "Hover controls: file tabs/numbers/close, tabpages, all tool tabs/actions/compact headers, Problems, confirmation, theme rows and dashboard; hover is safe and clicks still work"
