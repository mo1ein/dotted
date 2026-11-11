-- Attach a real remote terminal UI to fresh Neovim processes; no external client.
assert(vim.env.NVIM_TEST_ISOLATED == "1", "UI startup test requires isolated XDG dirs")
local function start(args, expected, inspect)
  local command = { vim.v.progpath, "--embed", "--cmd", "let g:dotted_ui_test=1" }
  vim.list_extend(command, args)
  local channel = vim.fn.jobstart(command, { rpc = true })
  assert(channel > 0)
  local ok, err = xpcall(function()
    vim.rpcrequest(channel, "nvim_ui_attach", 140, 42, { rgb = true })
    assert(vim.wait(10000, function()
      return vim.rpcrequest(channel, "nvim_exec_lua", "return vim.v.vim_did_enter == 1 and vim.bo.filetype", {}) == expected
    end, 30), "Unexpected startup view: " .. expected)
    local state = vim.rpcrequest(channel, "nvim_exec_lua", [[
      return { ft = vim.bo.filetype, status = vim.o.statusline, tabs = vim.o.tabline, error = vim.v.errmsg }
    ]], {})
    assert(state.status:find("ui.statusline", 1, true) and state.tabs:find("ui.bufferline", 1, true))
    assert(state.error == "", state.error)
    if inspect then inspect(channel) end
  end, debug.traceback)
  vim.fn.jobstop(channel)
  assert(ok, err)
end
start({}, "dashboard", function(channel)
  local screen = vim.rpcrequest(channel, "nvim_exec_lua", [[
    vim.cmd "Keymaps"
    vim.cmd.redraw()
    local lines = {}
    for row = 1, vim.o.lines do
      local line = ""
      for col = 1, vim.o.columns do line = line .. vim.fn.screenstring(row, col) end
      lines[#lines + 1] = line
    end
    vim.cmd.close()
    return table.concat(lines, "\n")
  ]], {})
  assert(screen:find("│", 1, true) and screen:find("Action", 1, true) and screen:find("macOS", 1, true), "Keymap table isn't rendered:\n" .. screen)
  assert(not screen:find("| --- |", 1, true), "Raw Markdown is visible in keymap preview")
  screen = vim.rpcrequest(channel, "nvim_exec_lua", [[
    vim.cmd.enew()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "cat cat cat" })
    _G.dotted_test_target = vim.api.nvim_get_current_buf()
    require("ui.replace").buffer { search = "cat", replacement = "dog" }
    vim.cmd.redraw()
    local lines = {}
    for row = 1, vim.o.lines do
      local line = ""
      for col = 1, vim.o.columns do line = line .. vim.fn.screenstring(row, col) end
      lines[#lines + 1] = line
    end
    return table.concat(lines, "\n")
  ]], {})
  for _, text in ipairs { "Search", "Replace with", "3 matches", "Alt-e expand" } do
    assert(screen:find(text, 1, true), "Replace UI missing " .. text .. ":\n" .. screen)
  end
  local geometry = vim.rpcrequest(channel, "nvim_exec_lua", "return vim.api.nvim_win_get_config(0)", {})
  assert(geometry.relative == "win" and geometry.height == 4 and geometry.row == 0 and geometry.col > 50, "Replace isn't a tiny top-right panel")
  vim.rpcrequest(channel, "nvim_input", "<M-e>")
  assert(vim.wait(5000, function()
    return vim.rpcrequest(channel, "nvim_exec_lua", "return vim.api.nvim_win_get_height(0)", {}) > 4
  end, 30), "Replace panel didn't expand")
  vim.rpcrequest(channel, "nvim_input", "<C-s>")
  assert(vim.wait(5000, function()
    return vim.rpcrequest(channel, "nvim_exec_lua", "return vim.api.nvim_buf_get_lines(_G.dotted_test_target,0,1,false)[1]", {}) == "dog dog dog"
  end, 30), "Real UI Replace All shortcut didn't edit the source buffer")
  vim.rpcrequest(channel, "nvim_input", "<Esc>q")
  assert(vim.wait(5000, function() return vim.rpcrequest(channel, "nvim_exec_lua", "return vim.bo.filetype", {}) ~= "dotted-replace" end, 30))
end)
local path = vim.fn.tempname() .. ".txt"
vim.fn.writefile({ "open the file, not the dashboard" }, path)
start({ path }, "text")
local function empty_project(channel, directory)
  assert(vim.rpcrequest(channel, "nvim_exec_lua", [[
    local expected = ...
    assert(vim.api.nvim_buf_get_name(0) == '', 'Directory startup left a named directory buffer')
    assert(vim.bo.buftype == '' and vim.bo.buflisted and vim.bo.modifiable, 'Directory startup is not a normal editable buffer')
    assert(vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_get_current_line() == '', 'Directory startup is not empty')
    assert(vim.uv.fs_realpath(vim.fn.getcwd()) == expected, 'Directory startup did not use the project working directory')
    assert(not package.loaded['nvim-tree'], 'Directory startup eagerly opened the explorer')
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      assert(vim.bo[buf].filetype ~= 'netrw', 'Directory startup loaded netrw')
      assert(vim.fn.isdirectory(vim.api.nvim_buf_get_name(buf)) == 0, 'Directory argument left an editor tab behind')
    end
    return true
  ]], { directory }))
  vim.rpcrequest(channel, "nvim_input", "istart editing<Esc>")
  assert(vim.wait(3000, function()
    return vim.rpcrequest(channel, "nvim_exec_lua", "return vim.api.nvim_get_current_line()", {}) == "start editing"
  end, 20), "Directory startup buffer is not editable")
end
start({ "." }, "", function(channel) empty_project(channel, vim.uv.fs_realpath(vim.fn.getcwd())) end)
local project = vim.fn.tempname() .. " startup project"
vim.fn.mkdir(project, "p")
start({ project }, "", function(channel) empty_project(channel, vim.uv.fs_realpath(project)) end)
print "Startup TUI: dashboard/file args preserved, dot/absolute directory args open empty editable project buffers, keymap display, replace UI, and status/buffer lines passed"
vim.cmd "qa!"
