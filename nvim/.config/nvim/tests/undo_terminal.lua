-- Command-Z bytes delivered by Ghostty, tested through a real Neovim TUI.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
if vim.fn.has "macunix" ~= 1 then print "Command-Z terminal: macOS-only bindings skipped"; return end
local file, socket = vim.fn.tempname() .. ".txt", vim.fn.tempname() .. ".sock"
vim.fn.writefile({ "" }, file)
local job = vim.fn.jobstart({ vim.v.progpath, "--listen", socket, file }, {
  pty = true, width = 150, height = 40, env = { TERM = "xterm-256color" },
  on_stdout = function(channel, data)
    local output = table.concat(data, "\n")
    if output:find("\27[6n", 1, true) then vim.fn.chansend(channel, "\27[1;1R") end
    if output:find("\27[?u", 1, true) then vim.fn.chansend(channel, "\27[?1u") end
  end,
})
local channel
local function lua(code) return vim.rpcrequest(channel, "nvim_exec_lua", code, {}) end
local function wait(code, message) assert(vim.wait(6000, function() return lua(code) == true end, 20), message) end
local ok, err = xpcall(function()
  assert(vim.wait(6000, function() return vim.uv.fs_stat(socket) ~= nil end, 20))
  channel = vim.fn.sockconnect("pipe", socket, { rpc = true })
  wait("return vim.bo.filetype=='text' and vim.v.vim_did_enter==1", "TUI did not start")
  vim.fn.chansend(job, "ihello\27")
  wait("return vim.api.nvim_get_current_line()=='hello' and vim.api.nvim_get_mode().mode=='n'", "Insert failed")
  vim.fn.chansend(job, "\27[122;9u")
  wait("return vim.api.nvim_get_current_line()==''", "Command-Z didn't undo")
  vim.fn.chansend(job, "\27[122;10u")
  wait("return vim.api.nvim_get_current_line()=='hello'", "Command-Shift-Z didn't redo")
  vim.fn.chansend(job, "A world")
  wait("return vim.api.nvim_get_current_line()=='hello world' and vim.api.nvim_get_mode().mode=='i'", "Insert setup failed")
  vim.fn.chansend(job, "\27[122;9u")
  wait("return vim.api.nvim_get_current_line()=='hello' and vim.api.nvim_get_mode().mode=='i'", "Insert-mode Command-Z failed")
  vim.fn.chansend(job, "\27[122;10u")
  wait("return vim.api.nvim_get_current_line()=='hello world' and vim.api.nvim_get_mode().mode=='i'", "Insert-mode Command-Shift-Z failed")
  assert(lua("return vim.v.errmsg==''"), lua("return vim.v.errmsg"))
end, debug.traceback)
if channel then pcall(vim.rpcnotify, channel, "nvim_command", "qa!") end
vim.fn.jobstop(job)
assert(ok, err)
print "Undo terminal: real Command-Z/Command-Shift-Z protocol bytes undo/redo in normal and insert mode passed"
