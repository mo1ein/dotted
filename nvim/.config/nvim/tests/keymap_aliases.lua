-- All presets retain leader/IDE mappings and add the four requested search aliases.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind) return kind == "config" and root or stdpath(kind) end
local keymaps = require "keymaps"
vim.fn.stdpath = stdpath
local previous_env, previous_preset = vim.env.NVIM_KEYMAP_PRESET, vim.g.keymap_preset
vim.env.NVIM_KEYMAP_PRESET = nil
local aliases = {
  ["find.buffer"] = { "F", "<leader>fz" },
  ["find.grep"] = { "<C-S-f>", "<leader>fg" },
  ["find.replace_buffer"] = { "<C-r>", "<leader>sR", "<leader>sb" },
  ["find.replace"] = { "<C-S-r>", "<leader>sr" },
}
local called
vim.api.nvim_create_user_command("FzfLua", function(args) called = args.args end, { nargs = "*" })
vim.api.nvim_create_user_command("Replace", function() called = "replace buffer" end, {})
vim.api.nvim_create_user_command("ReplaceProject", function() called = "replace project" end, {})
for _, preset in ipairs(keymaps.available()) do
  for _, os_name in ipairs { "linux", "macos" } do
    local resolved = {}
    for _, entry in ipairs(keymaps.resolve(os_name, preset).bindings) do resolved[entry.action] = entry.keys end
    for action, keys in pairs(aliases) do
      for _, key in ipairs(keys) do assert(vim.tbl_contains(resolved[action], key), preset .. "/" .. os_name .. " missing " .. key) end
    end
  end
  vim.g.keymap_preset = preset
  keymaps.setup()
  for key, command in pairs { F = "grep_curbuf", ["<C-S-f>"] = "live_grep", ["<C-r>"] = "replace buffer", ["<C-S-r>"] = "replace project" } do
    called = nil
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key:gsub("<leader>", " "), true, false, true), "xt", false)
    assert(called == command, preset .. ": " .. key .. " didn't execute " .. command)
  end
end
vim.env.NVIM_KEYMAP_PRESET, vim.g.keymap_preset = previous_env, previous_preset
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Search aliases: F/Ctrl-Shift-f/Space-sR/Ctrl-Shift-r execute correctly in all presets; leader/IDE keys preserved"
