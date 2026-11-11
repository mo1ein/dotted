-- JetBrains debug aliases resolve on all three OSes and execute existing actions.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind) return kind == "config" and root or stdpath(kind) end
local keymaps = require "keymaps"
vim.fn.stdpath = stdpath
vim.env.NVIM_KEYMAP_PRESET = nil
local aliases = {
  ["debug.continue"] = { "<leader>dc", "<S-F9>", "<F9>" },
  ["debug.breakpoint"] = { "<leader>db", "<C-F8>" },
  ["debug.step_over"] = { "<leader>do", "<F8>" },
  ["debug.step_into"] = { "<leader>di", "<F7>" },
  ["debug.step_out"] = { "<leader>dO", "<S-F8>" },
  ["debug.inspect"] = { "<leader>de", "<A-F8>" },
  ["debug.terminate"] = { "<leader>dx", "<C-S-F2>" },
  ["debug.ui"] = { "<leader>du", "<A-5>" },
}
local macos = { ["debug.breakpoint"] = "<D-F8>", ["debug.terminate"] = "<D-F2>", ["debug.ui"] = "<D-5>" }
local function entries(preset, os_name)
  local result = {}
  for _, entry in ipairs(keymaps.resolve(os_name, preset).bindings) do result[entry.action] = entry end
  return result
end
for _, preset in ipairs { "default", "jetbrains" } do
  for _, os_name in ipairs { "linux", "windows", "macos" } do
    local resolved = entries(preset, os_name)
    for action, keys in pairs(aliases) do
      for _, key in ipairs(keys) do assert(vim.tbl_contains(resolved[action].keys, key), preset .. "/" .. os_name .. " missing " .. key) end
    end
    if os_name == "macos" then
      for action, key in pairs(macos) do assert(vim.tbl_contains(resolved[action].keys, key)) end
      assert(vim.tbl_contains(resolved["debug.continue"].keys, "<C-d>") == (preset == "jetbrains"))
      assert(vim.tbl_contains(resolved["debug.continue"].keys, "<D-A-r>") == (preset == "jetbrains"))
    end
    -- No added debugger chord can silently shadow an unrelated preset action.
    for action in pairs(aliases) do
      for _, key in ipairs(resolved[action].keys) do
        for other_action, other in pairs(resolved) do
          if other_action ~= action then assert(not vim.tbl_contains(other.keys, key), key .. " conflicts with " .. other_action) end
        end
      end
    end
  end
end
local vscode = entries("vscode", "macos")
for action, key in pairs {
  ["debug.continue"] = "<F5>", ["debug.breakpoint"] = "<F9>", ["debug.step_over"] = "<F10>",
  ["debug.step_into"] = "<F11>", ["debug.step_out"] = "<S-F11>",
} do assert(vim.tbl_contains(vscode[action].keys, key), "VS Code debug layout changed") end

local called
local dap = {}
for action, method in pairs {
  ["debug.continue"] = "continue", ["debug.breakpoint"] = "toggle_breakpoint", ["debug.step_over"] = "step_over",
  ["debug.step_into"] = "step_into", ["debug.step_out"] = "step_out", ["debug.terminate"] = "terminate",
} do dap[method] = function() called = action end end
package.loaded.dap = dap
package.loaded.dapui = { eval = function() called = "debug.inspect" end }
package.loaded["ui.dap"] = { toggle = function() called = "debug.ui" end }
local platform = require "util.platform"
local platform_name = platform.name
for _, preset in ipairs { "default", "jetbrains" } do
  for _, os_name in ipairs { "linux", "windows", "macos" } do
    platform.name = function() return os_name end
    vim.g.keymap_preset = preset
    keymaps.setup()
    local resolved = entries(preset, os_name)
    for action in pairs(aliases) do
      for _, key in ipairs(resolved[action].keys) do
        called = nil
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key:gsub("<leader>", " "), true, false, true), "xt", false)
        assert(called == action, preset .. "/" .. os_name .. ": " .. key .. " did not execute " .. action)
      end
    end
    for _, key in ipairs(resolved["debug.inspect"].keys) do
      assert(vim.fn.maparg(key, "v", false, true).callback, "Visual expression inspection is missing")
    end
  end
end
platform.name = platform_name
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Debug keys: JetBrains aliases and leader keys execute for Linux/Windows/macOS mappings; visual inspection, no conflicts, and VS Code layout passed"
