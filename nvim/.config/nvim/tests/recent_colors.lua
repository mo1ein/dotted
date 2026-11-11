-- Attached UI: selected/hovered switcher rows share the workspace palette,
-- including inactive/insert-mode rendering and live dark/light theme changes.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", "--cmd", "let g:dotted_ui_test=1" }, { rpc = true })
assert(channel > 0)
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message)
  assert(vim.wait(5000, function() return lua(code) end, 10), message)
end
local function move(row)
  local at = lua([[
    vim.cmd.redraw()
    local row=...
    local s=require('ui.switcher').current()
    local p=vim.api.nvim_win_get_position(s.win)
    local top=vim.fn.getwininfo(s.win)[1].topline
    return {p[1]+row-top+1,p[2]+3}
  ]], { row })
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, at[1], at[2])
  wait("local s=require('ui.switcher').current();return s and s.hovered==" .. row, "Switcher row didn't hover")
end
local ok, err = xpcall(function()
  vim.rpcrequest(channel, "nvim_ui_attach", 150, 40, { rgb = true })
  wait("return vim.v.vim_did_enter==1", "Editor didn't start")
  local original = lua([[
    for _,buf in ipairs(require('ui.buffers').list()) do vim.bo[buf].buflisted=false end
    for i=1,12 do
      local buf=vim.api.nvim_create_buf(true,false)
      vim.api.nvim_buf_set_name(buf,vim.fn.tempname()..' color-'..i..'.txt')
      vim.api.nvim_buf_set_lines(buf,0,-1,false,{'unsaved '..i})
      vim.api.nvim_set_current_buf(buf)
    end
    vim.g.switcher_moves=0
    vim.keymap.set('n','<MouseMove>',function() vim.g.switcher_moves=vim.g.switcher_moves+1 end)
    require('ui.modifiers').is_down=function() return true end
    require('ui.switcher').cycle('next')
    local popup=vim.api.nvim_win_get_config(require('ui.switcher').current().win)
    assert(popup.row==math.max(0,math.floor((vim.o.lines-popup.height-2)/2)-3),'Switcher is not slightly above center')
    assert(popup.title_pos=='center' and vim.inspect(popup.title):find('Switcher',1,true),'Switcher title is missing from the top border')
    return {buf=vim.api.nvim_get_current_buf(),source=vim.api.nvim_get_current_win(),mru=require('ui.buffers').recent()}
  ]])
  for _, background in ipairs { "dark", "light" } do
    local palette = background == "dark" and { "#abcdef", "#234567" } or { "#123456", "#defabc" }
    lua([[
      local background,palette=...
      vim.g.fzf_colors={['fg+']=palette[1],['bg+']=palette[2]}
      vim.o.background=background
      vim.cmd.colorscheme('default')
      _G.SwitcherOriginalHighlights={}
      for _,name in ipairs {'PmenuSel','NormalFloat','Visual','CursorLine','FzfLuaFzfCursorLine'} do
        SwitcherOriginalHighlights[name]=vim.api.nvim_get_hl(0,{name=name,link=false,create=false})
      end
    ]], { background, palette })
    move(3)
    assert(lua([[
      local original,palette=...
      local s=require('ui.switcher').current()
      assert(s.selected==original.buf and s.index==2,'Hover changed the selected file')
      assert(vim.api.nvim_get_current_win()==original.source and vim.api.nvim_get_current_buf()==original.buf,'Hover changed focus/preview')
      assert(vim.deep_equal(original.mru,require('ui.buffers').recent()),'Hover reordered MRU')
      assert(vim.wo[s.win].winhighlight:find('CursorLine:DottedBreadcrumbSelection',1,true))
      local colors=require('ui.color').get('DottedBreadcrumbSelection')
      assert(colors.fg==tonumber(palette[1]:sub(2),16) and colors.bg==tonumber(palette[2]:sub(2),16),'Theme palette did not refresh')
      local marks=vim.api.nvim_buf_get_extmarks(s.buf,vim.api.nvim_create_namespace('DottedSwitcher'),0,-1,{details=true})
      assert(#marks==2,'Selected and hovered row highlights are missing')
      for _,mark in ipairs(marks) do assert(mark[4].hl_group=='DottedBreadcrumbSelection' and mark[4].hl_eol,'Rows do not use the common full-row role') end
      vim.cmd.redraw()
      local p=vim.api.nvim_win_get_position(s.win)
      local top=vim.fn.getwininfo(s.win)[1].topline
      local selected=vim.fn.screenattr(p[1]+s.index-top+2,p[2]+3)
      local hovered=vim.fn.screenattr(p[1]+s.hovered-top+2,p[2]+3)
      local ending=vim.fn.screenattr(p[1]+s.hovered-top+2,p[2]+vim.api.nvim_win_get_width(s.win)+1)
      assert(selected==hovered and hovered==ending,'Rendered row/text/padding colors differ')
      for name,before in pairs(SwitcherOriginalHighlights) do
        assert(vim.deep_equal(before,vim.api.nvim_get_hl(0,{name=name,link=false,create=false})),'Switcher changed '..name)
      end
      return true
    ]], { original, palette }))
    vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, 2, 2)
    wait("local s=require('ui.switcher').current();return s and not s.hovered", "Hover didn't clear outside popup")
  end
  lua("require('ui.switcher').finish(true)")
  vim.rpcrequest(channel, "nvim_input", "i")
  wait("return vim.api.nvim_get_mode().mode=='i'", "Insert mode didn't start")
  lua("require('ui.switcher').cycle('next')")
  move(3)
  assert(lua("return vim.api.nvim_get_mode().mode=='i' and require('ui.switcher').current().index==2"), "Hover left insert mode or selected another file")
  -- Scrolling the selection must hit-test displayed rows, not buffer row one.
  lua("for _=1,8 do require('ui.switcher').cycle('next') end")
  move(9)
  assert(lua("local s=require('ui.switcher').current();return s.index==10 and s.hovered==9 and vim.fn.getwininfo(s.win)[1].topline>1"), "Paged row hover is offset")
  lua("require('ui.modifiers').is_down=function() return false end")
  wait("return not require('ui.switcher').current()", "Release didn't close hovered popup")
  assert(lua("return vim.api.nvim_get_mode().mode=='i' and vim.bo.modified and vim.v.errmsg==''"), "Hover/release lost mode, edits or raised an error")
  lua("require('ui.modifiers').is_down=function() return true end;require('ui.switcher').cycle('next')")
  -- A stationary pointer must not keep stale hover marks from the old popup.
  assert(lua("return not require('ui.switcher').current().hovered"), "Reopened popup retained hover")
end, debug.traceback)
pcall(vim.rpcrequest, channel, "nvim_command", "qa!")
pcall(vim.fn.chanclose, channel)
assert(ok, err)
print "Recent colors: common selected/hover palette, full-row screen colors, live dark/light themes, safe normal/insert hover, paged rows and release passed"
