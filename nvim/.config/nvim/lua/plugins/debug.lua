-- Go/Python debugging; loaded only by a DAP command or module/keymap use.
return {
  {
    "mfussenegger/nvim-dap",
    cmd = { "DapContinue", "DapToggleBreakpoint", "DapToggleRepl" },
    dependencies = {
      "rcarriga/nvim-dap-ui", "nvim-neotest/nvim-nio", "leoluz/nvim-dap-go",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function() require "configs.dap" end,
  },
}
