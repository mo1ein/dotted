-- Attached UI: actual tabline/statusline/header mouse targets and keyboard input.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local directory = vim.fn.tempname() .. " dotted 项目 100%"
vim.fn.mkdir(directory .. "/.git", "p")
vim.fn.mkdir(directory .. "/nvim/.config", "p")
vim.fn.mkdir(directory .. "/nvim/sibling", "p")
vim.fn.writefile({ "sibling" }, directory .. "/nvim/sibling/inside.txt")
local file = directory .. "/nvim/.config/main.txt"
vim.fn.writefile({ "keep this source visible" }, file)
vim.fn.writefile({ "alpha" }, directory .. "/nvim/.config/alpha.txt")
vim.fn.writefile({ "zeta" }, directory .. "/nvim/.config/zeta.txt")
local channel = vim.fn.jobstart({ vim.v.progpath, "--embed", "--cmd", "let g:dotted_ui_test=1", file }, { rpc = true })
assert(channel > 0)
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message)
  local done = vim.wait(7000, function() return lua(code) end, 20)
  assert(done, message .. (done and "" or ("\n" .. lua("local s=require('ui.tools').current();return vim.inspect({mode=vim.api.nvim_get_mode(),ft=vim.bo.filetype,selected=s.selected,win=s.win,cur=vim.api.nvim_get_current_win(),messages=vim.fn.execute('messages')})"))))
end
local function position(label, where)
  local position = lua([[
    vim.cmd.redraw()
    local label, where = ...
    for row = 1, vim.o.lines do
      if not where or (where == 'bottom' and row >= vim.o.lines - 2) or (where == 'top' and row == 1) then
        local line = ''
        for col = 1, vim.o.columns do line = line .. vim.fn.screenstring(row,col) end
        local at = line:find(label,1,true)
        if at then return {row-1, vim.fn.strdisplaywidth(line:sub(1,at-1))} end
      end
    end
  ]], { label, where })
  assert(position, "Not visible/clickable: " .. label)
  return position
end
local function click(label, where, offset)
  local position = position(label, where)
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "press", "", 0, position[1], position[2] + (offset or 0))
  vim.rpcrequest(channel, "nvim_input_mouse", "left", "release", "", 0, position[1], position[2] + (offset or 0))
  return position
end
local function hover(label, where, offset)
  local position = position(label, where)
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, position[1], position[2] + (offset or 0))
  return position
end
local function screen()
  return lua([[
    vim.cmd.redraw()
    local rows = {}
    for row = 1, vim.o.lines do
      local line = ''
      for col = 1, vim.o.columns do line = line .. vim.fn.screenstring(row,col) end
      rows[#rows+1] = line
    end
    return table.concat(rows, '\n')
  ]])
end
local function status_labels(group)
  return lua([[
    local group = ...
    local status = vim.api.nvim_eval_statusline(vim.o.statusline, {maxwidth=vim.o.columns,highlights=true})
    local labels = {}
    for i,span in ipairs(status.highlights) do
      if span.group == group then
        local ending = status.highlights[i+1]
        labels[#labels+1] = status.str:sub(span.start+1, ending and ending.start or #status.str)
      end
    end
    return table.concat(labels, '|')
  ]], { group })
end
local function active_breadcrumb() return status_labels("DottedBreadcrumbActive") end
local ok, err = xpcall(function()
  vim.rpcrequest(channel, "nvim_ui_attach", 180, 44, { rgb = true })
  wait("return vim.bo.filetype == 'text'", "Source didn't open")
  assert(lua("return not package.loaded.neogit and not package.loaded.overseer and not package.loaded.trouble and not package.loaded.cybu"), "Workspace plugins loaded at startup")
  click("[1]", "top")
  assert(lua("return vim.bo.filetype == 'text'"))
  local original_cursor = lua("return vim.api.nvim_win_get_cursor(0)")
  lua("vim.g.hover_test_moves=0;vim.keymap.set('n','<MouseMove>',function() vim.g.hover_test_moves=vim.g.hover_test_moves+1 end)")
  hover("Tools", "bottom", 2)
  assert(vim.wait(2000, function() return status_labels("DottedStatuslineToolsHover"):find("Tools", 1, true) ~= nil end, 20), "Tools didn't react to hover")
  assert(lua("return not require('ui.tools').is_open()"), "Hover opened Tools without a click")
  hover(".config", "bottom", 3)
  assert(vim.wait(2000, function() return status_labels("DottedBreadcrumbHover") == ".config" end, 20), "Breadcrumb didn't react to hover")
  assert(status_labels("DottedStatuslineToolsHover") == "", "Tools retained hover after moving to a breadcrumb")
  hover("main.txt", "bottom", 2)
  local file_label = lua("return require('ui.file_icons').get('main.txt') .. ' main.txt'")
  assert(vim.wait(2000, function() return status_labels("DottedBreadcrumbHover") == file_label end, 20), "Filename/icon breadcrumb didn't react to hover")
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, 4, 40)
  assert(vim.wait(2000, function() return status_labels("DottedBreadcrumbHover") == "" end, 20), "Hover color stuck after leaving the bar")
  assert(vim.deep_equal(original_cursor, lua("return vim.api.nvim_win_get_cursor(0)")), "Hover moved the editor cursor")
  assert(lua("return vim.g.hover_test_moves >= 3"), "Statusline hover intercepted an existing mouse-motion mapping")
  lua("vim.keymap.del('n','<MouseMove>')")
  vim.rpcrequest(channel, "nvim_input", "i")
  wait("return vim.api.nvim_get_mode().mode == 'i'", "Insert-mode hover setup failed")
  hover("Tools", "bottom", 1)
  assert(vim.wait(2000, function() return status_labels("DottedStatuslineToolsHover"):find("Tools", 1, true) ~= nil end, 20), "Hover failed in insert mode")
  assert(lua("return vim.api.nvim_get_mode().mode == 'i'"), "Hover exited insert mode")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  local preferences = lua("return {cursor=vim.o.guicursor,mousemove=vim.o.mousemoveevent}")
  local breadcrumb_click = click(".config", "bottom", 4)
  wait("return vim.bo.filetype == 'dotted_menu'", "Breadcrumb mouse click didn't open a menu")
  wait("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('main.txt',1,true) ~= nil", "Directory menu didn't populate")
  local geometry = lua("return vim.api.nvim_win_get_config(0)")
  assert(geometry.col == math.min(breadcrumb_click[2], 180 - geometry.width - 2), "Breadcrumb menu is not aligned to the label's left edge")
  assert(geometry.row + geometry.height + 2 == breadcrumb_click[1], "Breadcrumb menu is not adjacent to its statusline")
  assert(not geometry.title, "Breadcrumb menu still has a path title")
  assert(active_breadcrumb() == ".config", "Open breadcrumb didn't get its own selected color")
  hover("nvim", "bottom", 1)
  assert(vim.wait(2000, function() return status_labels("DottedBreadcrumbHover") == "nvim" end, 20), "Breadcrumb hover failed with a menu open")
  assert(active_breadcrumb() == ".config", "Hover replaced the active menu's selected breadcrumb")
  hover("Tools", "bottom", 1)
  assert(vim.wait(2000, function() return status_labels("DottedStatuslineToolsHover"):find("Tools", 1, true) ~= nil end, 20), "Tools hover failed with a menu open")
  assert(lua("return vim.o.mousemoveevent and vim.o.guicursor:find('DottedMenuCursor',1,true) ~= nil"), "Menu didn't enable hover and hide its caret")
  -- Move onto the third row's padding, without clicking: only selection moves.
  vim.rpcrequest(channel, "nvim_input_mouse", "move", "", "", 0, geometry.row + 3, geometry.col + geometry.width - 1)
  wait("return vim.bo.filetype == 'dotted_menu' and vim.api.nvim_win_get_cursor(0)[1] == 3", "Mouse hover didn't select the row")
  assert(vim.wait(2000, function() return status_labels("DottedStatuslineToolsHover") == "" end, 20), "Bar hover stuck after entering the dropdown")
  assert(active_breadcrumb() == ".config", "Hover cleared the active breadcrumb")
  assert(lua("return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(require('ui.buffers').source_win() and vim.api.nvim_win_get_buf(require('ui.buffers').source_win()) or 0),':t') == 'main.txt'"), "Hover opened a file without a click")
  local painted = lua([[
    vim.cmd.redraw()
    local c=vim.api.nvim_win_get_config(0)
    local row=c.row+4
    return {left=vim.fn.screenattr(row,c.col+2),right=vim.fn.screenattr(row,c.col+c.width+1),other=vim.fn.screenattr(row-1,c.col+2)}
  ]])
  assert(painted.left == painted.right and painted.left ~= painted.other, "Hover didn't paint a full-row selection")
  -- Clicking another breadcrumb replaces the popup and its selected segment.
  click("nvim", "bottom", 1)
  wait("return vim.bo.filetype == 'dotted_menu' and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('.config',1,true) ~= nil", "Another breadcrumb didn't replace the menu")
  assert(active_breadcrumb() == "nvim", "Previous breadcrumb retained its selected color")
  assert(lua("local n=0;for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='dotted_menu' then n=n+1 end end return n==1"), "Switching breadcrumbs left duplicate menus")
  local parent_geometry = lua("return vim.api.nvim_win_get_config(0)")
  local navigation_window = lua("return vim.api.nvim_get_current_win()")
  vim.rpcrequest(channel, "nvim_input", "<Right>")
  wait("return vim.bo.filetype == 'dotted_menu' and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('main.txt',1,true) ~= nil", "Right didn't descend into the directory")
  assert(active_breadcrumb() == ".config", "Right didn't apply the selected directory to the breadcrumb")
  geometry = lua("return vim.api.nvim_win_get_config(0)")
  assert(geometry.col > parent_geometry.col, "Right didn't shift the menu right to the next breadcrumb")
  assert(geometry.row + geometry.height == parent_geometry.row + parent_geometry.height, "Directory descent detached the menu from the statusline")
  assert(lua("return vim.api.nvim_get_current_win() == " .. navigation_window), "Directory descent rebuilt the popup window")
  assert(not lua("return vim.api.nvim_eval_statusline(vim.o.statusline,{maxwidth=vim.o.columns}).str:find('main.txt',1,true) ~= nil"), "Breadcrumb still showed the previous file after choosing a directory")
  vim.rpcrequest(channel, "nvim_input", "<Left>")
  wait("return vim.bo.filetype == 'dotted_menu' and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('sibling',1,true) ~= nil", "Left didn't return to the parent directory")
  assert(active_breadcrumb() == "nvim", "Left didn't restore the parent breadcrumb")
  assert(lua("return vim.api.nvim_win_get_config(0).col == " .. parent_geometry.col), "Left didn't shift the menu back under its parent")
  click("sibling")
  wait("return vim.bo.filetype == 'dotted_menu' and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('inside.txt',1,true) ~= nil", "Mouse selection didn't descend into a sibling directory")
  assert(active_breadcrumb() == "sibling", "Sibling selection didn't replace the breadcrumb path")
  assert(lua("return vim.api.nvim_win_get_config(0).col > " .. parent_geometry.col), "Mouse directory selection didn't shift the pane right")
  click("sibling", "bottom", 2)
  wait("return vim.bo.filetype == 'dotted_menu' and table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('inside.txt',1,true) ~= nil", "Applied breadcrumb resolved to the previous source directory")
  assert(active_breadcrumb() == "sibling", "Reopening the applied breadcrumb lost its selected state")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return vim.bo.filetype == 'text'", "Breadcrumb Esc didn't restore source")
  assert(active_breadcrumb() == "", "Dismissed breadcrumb retained its selected color")
  local restored = lua("return {cursor=vim.o.guicursor,mousemove=vim.o.mousemoveevent}")
  assert(vim.deep_equal(preferences, restored), "Closing the dropdown changed editor cursor/mouse settings")
  vim.rpcrequest(channel, "nvim_input", " uB")
  wait("return vim.bo.filetype == 'dotted_menu'", "Keyboard breadcrumb menu didn't open")
  wait("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('main.txt',1,true) ~= nil", "Keyboard directory menu didn't populate")
  geometry = lua("return vim.api.nvim_win_get_config(0)")
  assert(geometry.col == math.min(breadcrumb_click[2], 180 - geometry.width - 2), "Keyboard menu didn't align to the directory label")
  assert(geometry.row + geometry.height + 2 == breadcrumb_click[1] and not geometry.title)
  click("main.txt")
  wait("return vim.bo.filetype == 'text'", "Clicking a menu item didn't open the file")
  assert(active_breadcrumb() == "", "File selection left an active breadcrumb")
  vim.rpcrequest(channel, "nvim_input", " uB")
  wait("return vim.bo.filetype == 'dotted_menu'", "Keyboard selection menu didn't open")
  wait("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('main.txt',1,true) ~= nil", "Keyboard selection menu didn't populate")
  vim.rpcrequest(channel, "nvim_input", "<Down><CR>")
  wait("return vim.bo.filetype == 'text' and vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0),':t') == 'main.txt'", "Keyboard selection didn't open the highlighted item")
  vim.rpcrequest(channel, "nvim_ui_try_resize", 95, 30)
  hover("…", "bottom")
  assert(vim.wait(2000, function() return status_labels("DottedBreadcrumbHover") == "…" end, 20), "Collapsed segment hover highlighted the root instead of the ellipsis")
  local collapsed = click("…", "bottom")
  wait("return vim.bo.filetype == 'dotted_menu'", "Collapsed breadcrumb didn't open")
  wait("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('nvim',1,true) ~= nil", "Collapsed breadcrumb didn't list the root")
  geometry = lua("return vim.api.nvim_win_get_config(0)")
  assert(geometry.col == math.min(collapsed[2], 95 - geometry.width - 2), "Collapsed breadcrumb menu didn't align to the ellipsis")
  assert(active_breadcrumb() == "…", "Collapsed breadcrumb highlighted both root and ellipsis")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return vim.bo.filetype == 'text'", "Collapsed breadcrumb didn't restore source")
  vim.rpcrequest(channel, "nvim_input", " uB")
  wait("return vim.bo.filetype == 'dotted_menu'", "Keyboard menu for a collapsed path didn't open")
  wait("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('main.txt',1,true) ~= nil", "Collapsed path keyboard menu didn't list the current directory")
  geometry = lua("return vim.api.nvim_win_get_config(0)")
  assert(geometry.col == math.min(collapsed[2], 95 - geometry.width - 2), "Hidden directory's keyboard menu didn't align to the ellipsis")
  assert(active_breadcrumb() == "…", "Keyboard menu didn't mark its collapsed breadcrumb")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return vim.bo.filetype == 'text'", "Collapsed path keyboard menu didn't restore source")
  vim.rpcrequest(channel, "nvim_ui_try_resize", 180, 44)
  local tree_geometry = lua([[
    local directory = ...
    require('lazy').load {plugins={'nvim-tree.lua'}}
    vim.cmd('NvimTreeOpen ' .. vim.fn.fnameescape(directory))
    for _,win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='NvimTree' then
        return {win=win,width=vim.api.nvim_win_get_width(win),height=vim.api.nvim_win_get_height(win)}
      end
    end
  ]], { directory })
  assert(tree_geometry, "NvimTree didn't open in attached UI")
  hover(".config", "bottom", 2)
  assert(vim.wait(2000, function() return status_labels("DottedBreadcrumbHover") == ".config" end, 20), "NvimTree focus broke breadcrumb hover")
  breadcrumb_click = click(".config", "bottom", 2)
  wait("return vim.bo.filetype == 'dotted_menu'", "Breadcrumb didn't open beside NvimTree")
  wait("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' '):find('main.txt',1,true) ~= nil", "Directory menu didn't populate beside NvimTree")
  geometry = lua("return vim.api.nvim_win_get_config(0)")
  assert(geometry.col == math.min(breadcrumb_click[2], 180 - geometry.width - 2), "NvimTree focus shifted the breadcrumb dropdown")
  assert(geometry.row + geometry.height + 2 == breadcrumb_click[1] and not geometry.title)
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return vim.bo.filetype == 'text'", "Breadcrumb didn't return to the editor")
  click("Tools", "bottom")
  wait("return require('ui.tools').is_open()", "Statusline Tools button didn't open the drawer")
  local drawer = lua("return require('ui.tools').current().win")
  local function stable_drawer()
    assert(lua("return require('ui.tools').current().win == " .. drawer), "Tool click recreated the drawer")
    assert(lua("return vim.api.nvim_win_get_width(" .. tree_geometry.win .. ") == " .. tree_geometry.width .. " and vim.api.nvim_win_get_height(" .. tree_geometry.win .. ") == " .. tree_geometry.height), "Tool click disturbed NvimTree geometry")
  end
  stable_drawer()
  lua("vim.cmd.startinsert()")
  wait("return vim.api.nvim_get_mode().mode == 't'", "Terminal-mode hover setup failed")
  hover("Tools", "bottom", 2)
  assert(vim.wait(2000, function() return status_labels("DottedStatuslineToolsHover"):find("Tools", 1, true) ~= nil end, 20), "Tools hover failed in terminal mode")
  assert(lua("return vim.api.nvim_get_mode().mode == 't'"), "Hover left terminal input mode")
  vim.rpcrequest(channel, "nvim_input", "<C-\\><C-n>")
  wait("return vim.api.nvim_get_mode().mode == 'nt' or vim.api.nvim_get_mode().mode == 'n'", "Terminal hover didn't retain normal-mode escape")
  lua([[vim.fn.chansend(vim.b.terminal_job_id, "echo DRAWER_TERMINAL_SENTINEL\n")]])
  assert(vim.wait(3000, function() return screen():find("DRAWER_TERMINAL_SENTINEL", 1, true) end, 20), "Terminal didn't paint its output")
  click("Output")
  wait("return require('ui.tools').current().selected == 'Output'", "Output header click didn't select its tab")
  stable_drawer()
  assert(not screen():find("DRAWER_TERMINAL_SENTINEL", 1, true), "Old terminal paint leaked into Output")
  for _ = 1, 2 do
    for _, name in ipairs { "Problems", "Debug", "Terminal", "Output" } do
      click(name)
      wait("return require('ui.tools').current().selected == '" .. name .. "' and require('ui.tools').is_open()", name .. " click failed")
      stable_drawer()
      local painted = screen()
      if name ~= "Terminal" then assert(not painted:find("DRAWER_TERMINAL_SENTINEL", 1, true), name .. " retained the old terminal paint") end
      if name == "Problems" then assert(painted:find("No problems reported", 1, true), "Problems didn't repaint") end
    end
  end
  vim.rpcrequest(channel, "nvim_input", "g3")
  wait("return require('ui.tools').current().selected == 'Problems' and require('ui.tools').is_open()", "Keyboard tab selection failed")
  local trigger = lua("local m=vim.fn.maparg('g4','n',false,true);return {desc=vim.fn.maparg('g','n',false,true).desc,definition=m.callback and debug.getinfo(m.callback,'S').linedefined,disable=require('which-key.config').disable}")
  assert(trigger.desc ~= "which-key-trigger", "Utility prefix intercepted: " .. vim.inspect(trigger))
  vim.rpcrequest(channel, "nvim_input", "g4")
  wait("return require('ui.tools').current().selected == 'Terminal' and require('ui.tools').is_open()", "Terminal tab keyboard selection failed")
  vim.rpcrequest(channel, "nvim_input", "gm")
  wait("return require('ui.tools').current().minimized == true", "Keyboard minimize failed")
  vim.rpcrequest(channel, "nvim_input", "gmgq")
  wait("return not require('ui.tools').is_open()", "Close didn't hide the drawer")
  lua("vim.cmd.enew(); vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. '.txt')")
  local previous = lua("return require('ui.buffers').recent()[2]")
  local recent_key = lua("for _,entry in ipairs(require('keymaps').current().bindings) do if entry.action=='buffer.recent_next' then return entry.keys[1] end end")
  lua("require('ui.modifiers').is_down=function() return true end")
  vim.rpcrequest(channel, "nvim_input", recent_key)
  wait("return vim.api.nvim_get_current_buf() == " .. previous, "Recent-file input didn't switch to the recent file")
  vim.rpcrequest(channel, "nvim_input", "<CR>")
  wait("return not require('ui.switcher').current()", "MRU popup didn't confirm")
  local edited = lua("return vim.api.nvim_get_current_buf()")
  local older = lua("return require('ui.buffers').recent()[2]")
  vim.rpcrequest(channel, "nvim_input", "iUNSAVED_SWITCHER_TEXT")
  wait("return vim.api.nvim_get_mode().mode == 'i'", "Insert mode didn't start")
  vim.rpcrequest(channel, "nvim_input", recent_key)
  wait("return vim.api.nvim_get_current_buf() == " .. older, "Insert-mode recent-file key failed")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  assert(lua("return table.concat(vim.api.nvim_buf_get_lines(" .. edited .. ",0,-1,false),'\\n'):find('UNSAVED_SWITCHER_TEXT',1,true) ~= nil"), "Insert-mode switching lost typed text")
  vim.rpcrequest(channel, "nvim_ui_try_resize", 65, 18)
  lua("require('ui.tools').show('Terminal'); vim.cmd.redraw()")
  assert(lua("return vim.v.errmsg == ''"), lua("return vim.v.errmsg"))
  lua("require('ui.tools').hide()")
end, debug.traceback)
vim.fn.jobstop(channel)
assert(ok, err)
print "Workspace TUI: Tools/breadcrumb hover in normal/insert/terminal modes, preserved mouse mappings, caret-free menu selection, applied paths, NvimTree compatibility, recent-file keys and resize passed"
