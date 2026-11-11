-- Native statusline regression tests, requiring no plugins or framework modules.
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(config)
local st = require "ui.statusline"
st.setup()
st.setup() -- no duplicate event handlers
require("config.highlights").setup()
require("themes.onedark").setup { transparent = true }
vim.cmd.colorscheme "dotted-onedark"
assert(#vim.api.nvim_get_autocmds { group = "OwnedStatusline", event = "LspProgress" } == 1)

local fixture = {
  active = true, mode = "n", filename = "main.lua", icon = "󰈚", width = 160,
  git = { head = "main", added = 2, changed = 1, removed = 3 },
  diagnostics = { [1] = 1, [2] = 2, [3] = 3, [4] = 4 },
  clients = { "lua_ls" }, cwd = "project", progress = "Indexing 4/8",
}
local function evaluate(ctx)
  return vim.api.nvim_eval_statusline(st.render(ctx), { maxwidth = 160, highlights = true })
end
local rendered = evaluate(fixture)
for _, part in ipairs { " NORMAL", "main.lua", " main", " 2", " 1", " 3", "Indexing 4/8", "LSP ~ lua_ls", "project" } do
  assert(rendered.str:find(part, 1, true), "Missing statusline section: " .. part)
end
assert(st.render(fixture):find("", 1, true) and st.render(fixture):find("", 1, true))
assert(vim.api.nvim_get_hl(0, { name = "DottedSt_NormalMode", link = false }).bg == 0x81a1c1)
assert(vim.api.nvim_get_hl(0, { name = "DottedSt_InsertMode", link = false }).bg == 0xc882e7)
assert(vim.api.nvim_get_hl(0, { name = "DottedSt_file", link = false }).bg == 0x2d3139)

local narrow = vim.tbl_extend("force", fixture, { width = 80, git = {}, clients = {}, diagnostics = {} })
local compact = evaluate(narrow).str
assert(not compact:find("Indexing", 1, true) and not compact:find("project", 1, true))
local inactive = evaluate(vim.tbl_extend("force", fixture, { active = false })).str
assert(not inactive:find("NORMAL", 1, true))
for mode, label in pairs { i = "INSERT", v = "VISUAL", V = "V-LINE", t = "TERMINAL", nt = "NTERMINAL", R = "REPLACE", c = "COMMAND", s = "SELECT", rm = "MORE", unknown = "NORMAL" } do
  assert(st.mode(mode) == label, "Wrong mode label: " .. mode)
end
local hostile = "100%#ErrorMsg#file.lua"
local escaped = evaluate(vim.tbl_extend("force", fixture, { filename = hostile })).str
assert(escaped:find(hostile, 1, true), "Filename percent signs were interpreted as statusline markup")

local function progress(kind, token)
  vim.api.nvim_exec_autocmds("LspProgress", {
    pattern = kind,
    data = { client_id = 1, params = { token = token, value = { kind = kind, title = "Indexing", percentage = 50 } } },
  })
end
progress("begin", "a")
progress("begin", "b")
progress("end", "a")
assert(st.progress["1:b"] and not st.progress["1:a"], "Concurrent progress tokens clobbered one another")
progress("end", "b")
assert(next(st.progress) == nil)

local user = require "config.highlights"
user.groups.DottedSt_file = { fg = "#123456" }
vim.cmd.colorscheme "habamax"
assert(vim.g.colors_name == "habamax")
assert(vim.api.nvim_get_hl(0, { name = "DottedSt_file", link = false }).fg == 0x123456)
vim.cmd.colorscheme "dotted-onedark"
assert(vim.api.nvim_get_hl(0, { name = "DottedSt_file", link = false }).fg == 0x123456)
local native = vim.api.nvim_eval_statusline(vim.o.statusline, { maxwidth = 160 })
assert(native.str ~= "", "Statusline option failed to render")
assert(not package.loaded.base46 and not package.loaded.nvconfig and not package.loaded.lualine)
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Statusline: layout, mode colors, widths, escaping, concurrent progress, overrides, and native rendering passed"
