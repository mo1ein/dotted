-- Cheatsheet includes plugin-owned tree help without creating global bindings.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind) return kind == "config" and root or stdpath(kind) end
local keymaps = require "keymaps"
vim.fn.stdpath = stdpath
local renderer = require "keymaps.table"
local document = table.concat(renderer.render_all(), "\n")
for _, text in ipairs {
  "NvimTree", "only while focused", "`g?`", "`<C-v>`", "`<C-x>`", "`<C-t>`",
  "Recent-file switcher", "Release Option", "`<A-Tab>`", "`<A-S-Tab>`", "`<CR>`", "`<Esc>`", "`<C-c>`",
  "Tools drawer", "`g1`", "`g4`", "`gq`", "`gm`", "`gL`", "`g+`", "`]t`", "`[t`",
  "Breadcrumbs and menus", "Problems drawer", "Confirmations", "Dashboard", "Replace widget",
} do assert(document:find(text, 1, true), "Cheatsheet missing " .. text) end
keymaps.setup()
vim.cmd "Keymaps"
local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(vim.bo.filetype == "keymaps", "Keymap preview activates Markdown plugins")
assert(content:find("╭", 1, true) and content:find("│", 1, true), "Keymap tables aren't rendered")
assert(not content:find("| --- |", 1, true) and not content:find("`", 1, true), "Preview still shows raw Markdown")
for _, header in ipairs { "Action", "Description", "Mode", "Linux", "macOS", "Modifier" } do
  assert(content:find(header, 1, true), "Keymap table lost " .. header)
end
assert(not vim.wo.wrap and vim.wo.conceallevel == 0)
assert(content:find("g?", 1, true), "Interactive cheatsheet is missing tree help")
assert(vim.fn.maparg("g?", "n") == "", "Tree-only help became a global mapping")
assert(vim.fn.maparg("gq", "n") == "", "Tool-only control became a global mapping")
local grouped = vim.inspect(renderer.sections("default", "macos"))
assert(grouped:find("Release Option", 1, true) and grouped:find("Tools drawer", 1, true), "Grouped Cheatsheet lost context controls")
for _, size in ipairs { 20, 40, 80, 120 } do
  local rows = require("ui.keymap_preview").render(vim.split(document, "\n"), size)
  for _, row in ipairs(rows) do assert(vim.fn.strdisplaywidth(row) <= size, "Rendered table overflows its window") end
end
local escaped = require("ui.keymap_preview").render({ "| Key | Action |", "| --- | --- |", "| `<C-w>\\|` | Maximize |" }, 60)
assert(table.concat(escaped, "\n"):find("<C-w>|", 1, true), "Literal pipe key broke the table")
vim.api.nvim_exec_autocmds("VimResized", {})
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Cheatsheet: switcher release/confirm/cancel and scoped workspace controls in grouped/floating/exported tables; no global mapping added"
