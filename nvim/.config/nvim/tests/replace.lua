-- Offline buffer replacement: no disk writes, literal/regex/case/word, and UI.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local engine = require "util.replace"
local buf = vim.api.nvim_get_current_buf()
local function text(value) vim.api.nvim_buf_set_lines(buf, 0, -1, false, { value }) end
local function line() return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] end
text "cat CAT scatter cat."
assert(#engine.scan(buf, "cat", {}) == 4)
assert(#engine.scan(buf, "cat", { word = true }) == 3)
assert(#engine.scan(buf, "cat", { case_sensitive = true }) == 3)
assert(engine.apply(buf, "cat", "dog", { word = true }) == 3)
assert(line() == "dog dog scatter dog.")
text "a.b aXb a.b"
assert(engine.apply(buf, "a.b", "&\\1~", {}, 2) == 1)
assert(line() == "a.b aXb &\\1~", "Literal replacement interpreted metacharacters")
text "ab12 ab34"
assert(engine.apply(buf, "ab([0-9]+)", "id\\1", { regex = true }) == 2)
assert(line() == "id12 id34")
text "你好 hello 你好"
assert(engine.apply(buf, "你好", "", {}) == 2 and line() == " hello ")
assert(engine.apply(buf, "", "anything", {}) == 0)
assert(not engine.scan(buf, "(", { regex = true }))
text "cat"
assert(not engine.apply(buf, "cat", "\\=system('false')", { regex = true }))
assert(line() == "cat")
vim.bo[buf].readonly = true
assert(not engine.apply(buf, "cat", "dog", {}))
vim.bo[buf].readonly = false

local ui = require "ui.replace"
local panel = ui.buffer { search = "cat", replacement = "dog" }
assert(#panel.matches == 1 and line() == "cat", "Preview edited the target")
assert(vim.api.nvim_win_get_config(panel.win).relative == "win" and vim.api.nvim_win_get_config(panel.win).win == panel.origin)
assert(vim.api.nvim_win_get_width(panel.win) == require("ui.panel").replace_options("test", "buffer").width)
assert(vim.api.nvim_win_get_height(panel.win) == 4 and vim.api.nvim_win_get_config(panel.win).row <= 1)
vim.fn.maparg("<M-e>", "n", false, true).callback()
assert(panel.expanded and vim.api.nvim_win_get_height(panel.win) > 4)
vim.fn.maparg("<M-e>", "n", false, true).callback()
assert(not panel.expanded and vim.api.nvim_win_get_height(panel.win) == 4)
assert(panel.apply(true) == 1 and line() == "dog")
assert(vim.bo[buf].modified, "Buffer replacement didn't remain unsaved")
vim.api.nvim_exec_autocmds("VimResized", {})
ui.close()
assert(not vim.api.nvim_win_is_valid(panel.win) and panel.timer:is_closing())
assert(#vim.api.nvim_buf_get_extmarks(buf, panel.namespace, 0, -1, {}) == 0)
print "Replace: literal/regex/case/word, Unicode, selected/all, safe preview, unsaved edits, read-only checks, and popup cleanup passed"
