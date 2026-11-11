-- Integration tests: lazy loading, native completion, every preset, and saving.
-- Run with isolated XDG_CONFIG_HOME and XDG_STATE_HOME; writes confirmed choices.
assert(vim.env.NVIM_TEST_ISOLATED == "1", "Theme tests require isolated XDG dirs and NVIM_TEST_ISOLATED=1")
local loader = require "config.theme_loader"
local catalog = require "themes.catalog"
local plugins = require("lazy.core.config").plugins
local active = loader.startup()
local initial = catalog.find(active)
assert(not package.loaded["themes.bundled"] or (initial and initial.bundled), "Bundled palettes were parsed at startup")
for _, entry in ipairs(catalog.entries()) do
  if entry.plugin then
    local should_load = initial and initial.name == entry.name
    assert(not not plugins[entry.name]._.loaded == not not should_load, "Inactive theme loaded at startup: " .. entry.name)
  end
end
local native = vim.fn.getcompletion("", "color")
local before = vim.uv.fs_stat(vim.fn.stdpath "cache" .. "/theme-index/schemes")
local rtp = vim.o.rtp
catalog.index()
local after = vim.uv.fs_stat(vim.fn.stdpath "cache" .. "/theme-index/schemes")
assert(before.mtime.sec == after.mtime.sec and before.mtime.nsec == after.mtime.nsec, "Unchanged index was rewritten")
assert(vim.o.rtp == rtp, "Index setup duplicated a runtime path")

local count = 0
for _, entry in ipairs(catalog.entries()) do
  for _, scheme in ipairs(entry.schemes) do
    assert(vim.tbl_contains(native, scheme), scheme .. " missing from native completion")
    vim.cmd.colorscheme(scheme) -- use native command, not the custom loader API
    assert(vim.g.colors_name, scheme .. " failed to activate")
    assert(loader.current() == scheme, scheme .. " selection was not tracked")
    if entry.plugin then assert(plugins[entry.name]._.loaded, scheme .. " provider did not load") end
    if vim.tbl_contains(entry.light or {}, scheme) then assert(vim.o.background == "light", scheme .. " did not switch to light") end
    assert(vim.o.statusline:find("ui.statusline", 1, true), "Statusline was replaced")
    local status = vim.api.nvim_eval_statusline(vim.o.statusline, { maxwidth = 160 })
    assert(status.str ~= "", scheme .. " broke statusline rendering")
    count = count + 1
  end
end
vim.cmd "Theme! jb"
assert(require("themes.selection").read() == "jb")
assert(vim.g.colors_name == "jb")
vim.cmd "ThemeReset"
assert(require("themes.selection").read() == nil)
assert(loader.current() == require("config.theme").colorscheme)

-- The dependency-free floating picker previews on cursor movement and restores
-- the exact theme on Escape. It doesn't rely on vim.ui.select hover callbacks.
local executable = vim.fn.executable
local confirmation = require "ui.confirm"
local original_confirm = confirmation.open
confirmation.open = function(message, callback)
  assert(message:find("Use", 1, true))
  callback(true)
end
vim.fn.executable = function() return 0 end
local current = loader.current()
local popup = loader.pick()
assert(vim.api.nvim_win_get_height(popup.win) <= 10, "Native picker height wasn't halved")
local lines = vim.api.nvim_buf_get_lines(popup.buf, 0, -1, false)
local target
for i, name in ipairs(lines) do if name == "jb" then target = i; break end end
assert(target, "jb missing from native picker")
vim.api.nvim_win_set_cursor(popup.win, { target, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = popup.buf })
assert(vim.wait(1000, function() return loader.current() == "jb" end, 10))
vim.fn.maparg("<Esc>", "n", false, true).callback()
assert(loader.current() == current, "Canceling the picker didn't restore the original")
popup = loader.pick()
vim.api.nvim_win_set_cursor(popup.win, { target, 0 })
vim.fn.maparg("<CR>", "n", false, true).callback()
assert(vim.g.colors_name == "jb")
vim.fn.executable = executable
local previous_fzf = package.loaded["fzf-lua"]
local previous_shell = package.loaded["fzf-lua.shell"]
local hover
package.loaded["fzf-lua.shell"] = {
  stringify_data = function(callback) hover = callback; return "preview-callback" end,
}
vim.fn.executable = function(name) return name == "fzf" and 1 or executable(name) end
package.loaded["fzf-lua"] = {
  fzf_exec = function(items, opts)
    assert(vim.tbl_contains(items, "jb") and opts.prompt == "Themes> ")
    assert(opts.preview == "preview-callback")
    assert(opts.winopts.height == 0.425, "fzf picker height wasn't halved")
    hover { "zed-one-dark" }
    assert(vim.wait(1000, function() return loader.current() == "zed-one-dark" end, 10))
    opts.winopts.on_close()
    opts.actions.enter { "dotted-onedark" }
  end,
}
loader.pick()
vim.wait(50)
assert(loader.current() == "dotted-onedark")
package.loaded["fzf-lua"], vim.fn.executable = previous_fzf, executable
package.loaded["fzf-lua.shell"] = previous_shell
confirmation.open = original_confirm
require("themes.selection").reset()
-- Reset the startup cache too, without relying on the test's temporary choice.
vim.cmd "ThemeReset"
loader.apply(active)
assert(vim.v.errmsg == "", vim.v.errmsg)
print(count .. " catalog schemes passed; inactive providers stay unloaded, completion/picker/save/reset work")
vim.cmd "qa!"
