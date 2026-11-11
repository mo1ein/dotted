-- Real rg/grug-far replacement in a disposable project, including unsaved guards.
local directory = vim.fn.tempname() .. " project with spaces"
vim.fn.mkdir(directory, "p")
local first, second = directory .. "/one.txt", directory .. "/two.txt"
vim.fn.writefile({ "old old" }, first)
vim.fn.writefile({ "old" }, second)
local ui = require "ui.replace"
local function content(path) return table.concat(vim.fn.readfile(path), "\n") end
local function wait(predicate, message) assert(vim.wait(10000, predicate, 20), message) end
local instance = ui.project { root = directory, prefills = { search = "old", replacement = "new" } }
wait(function() local status = instance:get_status_info(); return status.stats and status.stats.matches == 3 end, "Project preview didn't find all matches")
assert(content(first) == "old old" and content(second) == "old", "Preview modified files")
local win = vim.api.nvim_get_current_win()
local config = vim.api.nvim_win_get_config(win)
assert(config.relative == "win" and config.width == require("ui.panel").replace_options("test", "project").width)
assert(config.row <= 1 and config.height <= 9, "Project replace isn't compact/top-aligned")
vim.fn.maparg("<M-e>", "n", false, true).callback()
assert(vim.api.nvim_win_get_height(win) > 9)
vim.fn.maparg("<M-e>", "n", false, true).callback()
assert(vim.api.nvim_win_get_height(win) == config.height)
local corner = type(config.border[1]) == "table" and config.border[1][1] or config.border[1]
assert(corner == "╭", "Replace doesn't use the rounded finder border")
local buffer = vim.fn.bufadd(first)
vim.fn.bufload(buffer)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "unsaved" })
local notify, warned = vim.notify, false
vim.notify = function(message) if message:find("Save modified", 1, true) then warned = true else notify(message) end end
vim.fn.maparg("<C-s>", "n", false, true).callback()
vim.notify = notify
assert(warned and content(first) == "old old", "Project replacement overwrote unsaved edits")
-- The engine hook also protects API calls and grug-far's other write actions.
instance:replace()
wait(function() return instance:get_status_info().status == "error" end, "Engine didn't reject an unsaved file")
assert(content(first) == "old old" and content(second) == "old", "Engine hook allowed a partial dirty-buffer replacement")
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "old old" })
vim.bo[buffer].modified = false
vim.fn.maparg("<C-s>", "n", false, true).callback()
wait(function() return content(first) == "new new" and content(second) == "new" end, "Project replacement failed")
wait(function() return instance:get_status_info().status ~= "progress" end, "Project replacement didn't finish")
vim.api.nvim_exec_autocmds("VimResized", {})
instance:close()

-- In-file replacement works on unsaved data and is undone without touching disk.
vim.cmd.edit(vim.fn.fnameescape(first))
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved cat cat" })
-- End the setup edit's undo block, as real user input does before invoking Replace.
vim.cmd "let &undolevels = &undolevels"
local target = vim.api.nvim_get_current_buf()
local panel = ui.buffer { search = "cat", replacement = "dog" }
assert(panel.apply(true) == 2)
ui.close()
assert(content(first) == "new new", "In-file replacement wrote to disk")
vim.cmd.undo()
assert(vim.api.nvim_buf_get_lines(target, 0, 1, false)[1] == "unsaved cat cat", "In-file replacement wasn't one undo step")
vim.bo[target].modified = false
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Replace: real project preview/apply across files, spaced paths, matching float, unsaved-file guard, and in-file undo passed"
vim.cmd "qa!"
