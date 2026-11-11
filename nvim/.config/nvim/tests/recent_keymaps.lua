-- macOS Option-Tab MRU keys; other platforms keep their existing Page keys.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind) return kind == "config" and root or stdpath(kind) end
local keymaps = require "keymaps"
vim.fn.stdpath = stdpath
local platform = require "util.platform"
local original_name = platform.name
local called
package.loaded["ui.switcher"] = { cycle = function(direction) called = direction end }
for _, preset in ipairs(keymaps.available()) do
  for _, os_name in ipairs { "macos", "linux", "windows" } do
    local next_key = os_name == "macos" and "<A-Tab>" or "<C-PageDown>"
    local prev_key = os_name == "macos" and "<A-S-Tab>" or "<C-PageUp>"
    local resolved = {}
    for _, entry in ipairs(keymaps.resolve(os_name, preset).bindings) do resolved[entry.action] = entry.keys end
    assert(vim.deep_equal(resolved["buffer.recent_next"], { next_key }))
    assert(vim.deep_equal(resolved["buffer.recent_prev"], { prev_key }))
    platform.name = function() return os_name end
    vim.env.NVIM_KEYMAP_PRESET, vim.g.keymap_preset = nil, preset
    keymaps.setup()
    for _, mode in ipairs { "n", "i" } do
      for key, direction in pairs { [next_key] = "next", [prev_key] = "prev" } do
        local mapping = vim.fn.maparg(key, mode, false, true)
        assert(mapping.callback, preset .. "/" .. os_name .. "/" .. mode .. " missing " .. key)
        called = nil
        mapping.callback()
        assert(called == direction, key .. " ran the wrong recent-file action")
      end
      for _, key in ipairs { "<C-Tab>", "<C-S-Tab>", "<C-A-Tab>", "<C-A-S-Tab>" } do
        assert(not vim.fn.maparg(key, mode, false, true).callback, "Conflicting old MRU chord remains mapped: " .. key)
      end
      if os_name == "macos" then
        for _, key in ipairs { "<C-PageDown>", "<C-PageUp>" } do
          assert(not vim.fn.maparg(key, mode, false, true).callback, "Old Ctrl-Fn MRU chord remains mapped: " .. key)
        end
      end
    end
  end
end
platform.name = original_name
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Recent keys: macOS Option-Tab/Option-Shift-Tab in every preset and normal/insert mode; old Ctrl-Fn/Tab chords removed; other platforms unchanged"
