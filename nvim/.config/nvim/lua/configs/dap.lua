-- Go/Python debug adapters, shared UI lifecycle, and breakpoint signs; no LSP coupling.
local dap = require "dap"
local config = require "config.debug"
local delve = config.delve or vim.fn.exepath "dlv"
if delve == "" and vim.fn.executable(vim.fn.expand "~/go/bin/dlv") == 1 then delve = vim.fn.expand "~/go/bin/dlv" end
if not delve or delve == "" then
  delve = "dlv"
  vim.notify("Delve is missing. Install with: go install github.com/go-delve/delve/cmd/dlv@latest", vim.log.levels.WARN)
end

require("ui.dap").setup(dap)
dap.listeners.after.event_initialized.dotted_toolbar = function(session)
  require("util.debug_session").remember(session)
  vim.cmd.redrawtabline()
end
dap.listeners.after.launch.dotted_toolbar = function(session, err)
  if err then require("util.debug_session").failed()
  else require("util.debug_session").remember(session) end
end
-- Completion keeps the selected Debug configuration available for rerun.
require("nvim-dap-virtual-text").setup()

require("dap-go").setup {
  delve = { path = delve, initialize_timeout_sec = config.timeout },
  dap_configurations = {
    { type = "go", name = "Go: current package", request = "launch", mode = "debug", program = "${fileDirname}", cwd = "${fileDirname}" },
    { type = "go", name = "Go: current file", request = "launch", mode = "debug", program = "${file}", cwd = "${fileDirname}" },
    { type = "go", name = "Go: tests in package", request = "launch", mode = "test", program = "${fileDirname}", cwd = "${fileDirname}" },
  },
}

-- Delve's launch.cwd controls the debuggee, not the Go compiler's directory.
-- Start the adapter inside the module so launches work from any Neovim cwd.
local go_adapter = dap.adapters.go
dap.adapters.go = function(callback, client)
  go_adapter(function(adapter)
    adapter = vim.deepcopy(adapter)
    local program = type(client.program) == "string" and client.program or vim.api.nvim_buf_get_name(0)
    adapter.executable.cwd = client.cwd or vim.fs.root(program, "go.mod") or vim.fn.getcwd()
    callback(adapter)
  end, client)
end

require("configs.dap_python").setup(dap)

vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "Comment" })
vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticInfo", linehl = "Visual" })
