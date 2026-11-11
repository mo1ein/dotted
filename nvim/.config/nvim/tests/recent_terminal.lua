-- Real modified-key bytes through a Neovim TUI/PTY, without terminal config
-- changes: Option-Tab/Shift on macOS, existing Ctrl-PageDown/Up elsewhere.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
if vim.fn.has("win32") == 1 then print "Recent terminal: Unix PTY test skipped on Windows"; return end
local macos = require("util.platform").name() == "macos"
local forward = macos and "\27[9;3u" or "\27[6;5~"
local reverse = macos and "\27[9;4u" or "\27[5;5~"
local directory = vim.fn.tempname() .. " recent files"
vim.fn.mkdir(directory, "p")
for _, name in ipairs { "a.txt", "b.txt", "c.txt" } do vim.fn.writefile({ name }, directory .. "/" .. name) end
local socket = vim.fn.tempname() .. ".sock"
local job = vim.fn.jobstart({ vim.v.progpath, "--listen", socket, "--cmd", "let g:dotted_ui_test=1", directory .. "/a.txt" }, {
  pty = true, width = 150, height = 40, env = { TERM = "xterm-256color" },
  on_stdout = function(channel, data)
    local output = table.concat(data, "\n")
    if output:find("\27[6n", 1, true) then vim.fn.chansend(channel, "\27[1;1R") end
    if output:find("\27[?u", 1, true) then vim.fn.chansend(channel, "\27[?1u") end
  end,
})
assert(job > 0)
local channel
local function lua(code, args) return vim.rpcrequest(channel, "nvim_exec_lua", code, args or {}) end
local function wait(code, message)
  assert(vim.wait(7000, function() return lua(code) end, 20), message .. "\n" .. lua("return vim.inspect {mode=vim.api.nvim_get_mode(),buf=vim.api.nvim_get_current_buf(),messages=vim.fn.execute('messages') }"))
end
local ok, err = xpcall(function()
  assert(vim.wait(7000, function() return vim.uv.fs_stat(socket) ~= nil end, 20), "Neovim didn't create its RPC socket")
  channel = vim.fn.sockconnect("pipe", socket, { rpc = true })
  assert(channel > 0)
  wait("return vim.v.vim_did_enter==1 and vim.bo.filetype=='text'", "TUI didn't finish starting")
  local files = lua([[
    local directory=...
    require('ui.modifiers').is_down=function() return true end -- synthetic Option hold
    local files={vim.api.nvim_get_current_buf()}
    for _,name in ipairs {'b.txt','c.txt'} do
      vim.cmd.edit(vim.fn.fnameescape(directory..'/'..name))
      files[#files+1]=vim.api.nvim_get_current_buf()
    end
    vim.api.nvim_buf_set_lines(0,0,-1,false,{'unsaved recent-file text'})
    return files
  ]], { directory })
  local function key(bytes, expected, message)
    vim.fn.chansend(job, bytes)
    wait("return vim.api.nvim_get_current_buf()==" .. expected, message)
  end
  local function closed()
    if macos then lua("require('ui.modifiers').is_down=function() return false end")
    else vim.rpcrequest(channel, "nvim_input", "<CR>") end
    wait("return not require('ui.switcher').current()", "MRU popup didn't confirm on release/Enter")
    lua("require('ui.modifiers').is_down=function() return true end")
  end
  key(forward, files[2], "Recent-file key didn't switch to the recent file")
  key(reverse, files[3], "Reverse recent-file key didn't cycle backward")
  closed()
  vim.fn.chansend(job, "i")
  wait("return vim.api.nvim_get_mode().mode=='i'", "Insert-mode setup failed")
  key(forward, files[2], "Recent-file key failed in insert mode")
  key(reverse, files[3], "Reverse recent-file key failed in insert mode")
  closed()
  wait("return vim.api.nvim_get_mode().mode=='i'", "Release left insert mode")
  local before = lua("return vim.api.nvim_buf_get_lines(0,0,-1,false)")
  key(forward, files[2], "Insert confirmation setup failed")
  key(reverse, files[3], "Insert confirmation reverse failed")
  vim.rpcrequest(channel, "nvim_input", "<CR>")
  wait("return not require('ui.switcher').current()", "Insert Enter didn't confirm")
  assert(vim.deep_equal(before, lua("return vim.api.nvim_buf_get_lines(0,0,-1,false)")), "Confirm inserted a newline")
  key(forward, files[2], "Insert cancellation setup failed")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  wait("return not require('ui.switcher').current() and vim.api.nvim_get_current_buf()==" .. files[3], "Insert Esc didn't restore original")
  wait("return vim.api.nvim_get_mode().mode=='i'", "Cancel unexpectedly left insert mode")
  vim.rpcrequest(channel, "nvim_input", "<Esc>")
  assert(lua("return vim.bo[" .. files[3] .. "].modified and vim.api.nvim_buf_get_lines(" .. files[3] .. ",0,1,false)[1]=='unsaved recent-file text'"), "A chord inserted text or discarded unsaved edits")
  key("\t", files[1], "Plain Tab no longer performs sequential navigation")
  assert(lua("return vim.v.errmsg==''"), lua("return vim.v.errmsg"))
end, debug.traceback)
if channel then
  -- Nvim's TUI owns a separate embedded server. Stop the isolated test server
  -- explicitly so terminating its PTY does not leave an orphan editor behind.
  pcall(vim.rpcrequest, channel, "nvim_command", "qa!")
  pcall(vim.fn.chanclose, channel)
end
if vim.fn.jobwait({ job }, 0)[1] == -1 then vim.fn.jobstop(job) end
assert(ok, err)
print "Recent terminal: real Option-Tab/Shift input on macOS, normal/insert MRU cycling, unchanged plain Tab and unsaved text passed without terminal remapping"
