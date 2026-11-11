-- The toolbar must not ask nvim-dap to select an action for a live session.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.api.nvim_buf_set_name(0, "/tmp/dotted-debug-starting.lua")
vim.bo.filetype = "lua"
vim.bo.buflisted = true
local notices, continues = {}, 0
local original_notify = vim.notify
vim.notify = function(message) notices[#notices + 1] = message end
local opened = 0
package.loaded["ui.dap"] = { open = function()
  opened = opened + 1
  vim.cmd "vsplit"
  local panel = vim.api.nvim_create_buf(false, true)
  vim.bo[panel].filetype = "dapui_console"
  vim.api.nvim_win_set_buf(0, panel)
end }
package.loaded.dap = {
  session = function() return { initialized = false } end,
  continue = function() continues = continues + 1 end,
}
assert(require("util.run").debug())
assert(continues == 0 and notices[#notices] == "Debugger is starting")
package.loaded.dap.session = function() return { initialized = true } end
assert(require("util.run").debug())
assert(continues == 0 and notices[#notices] == "Debug session is already running", vim.inspect { continues = continues, notices = notices })
package.loaded.dap.session = function() return { initialized = true, stopped_thread_id = 1 } end
assert(require("util.run").debug())
assert(continues == 1)
local launched
package.loaded.dap.session = function() return nil end
package.loaded.dap.configurations = { lua = { { name = "Lua file", request = "launch", program = "${file}" } } }
package.loaded.dap.run = function(config) launched = config end
assert(require("util.run").debug())
assert(launched and launched.name == "Lua file", "Opening Debug UI stole the launch filetype")
assert(opened == 4, "Debug button didn't open the Debug panel")
vim.notify = original_notify
print "Debug button: initializing sessions do not prompt; active sessions do not prompt; stopped sessions continue"
