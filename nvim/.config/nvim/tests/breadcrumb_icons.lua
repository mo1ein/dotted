-- Correct extension-specific glyphs in the path and its dropdown, with no
-- redraw-time plugin loading or changes to selection/highlight ownership.
assert(vim.env.NVIM_TEST_ISOLATED == "1")
local icons = require "ui.file_icons"
local devicons = assert(package.loaded["nvim-web-devicons"], "Eager devicons plugin wasn't initialized")
local breadcrumbs = require "ui.breadcrumbs"
local root = vim.fn.tempname() .. " icons"
vim.fn.mkdir(root .. "/.git", "p")
vim.fn.mkdir(root .. "/folder", "p")
vim.fn.writefile({ "source" }, root .. "/source.txt")
vim.cmd.edit(vim.fn.fnameescape(root .. "/source.txt"))
local source, original = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
local expected = {}
for _, name in ipairs { "readme.md", "main.py", "main.go", "unknown.unrecognized_extension" } do
  vim.fn.writefile({ name }, root .. "/" .. name)
  local extension = name:match("%.([^%.]+)$")
  expected[name] = devicons.get_icon(name, extension, { default = true })
  if name ~= "unknown.unrecognized_extension" then assert(expected[name] ~= icons.fallback, "Known file type has no distinctive icon: " .. name) end
  assert(icons.get(name) == expected[name], "Extension was not passed to devicons: " .. name)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, root .. "/" .. name)
  vim.api.nvim_win_set_buf(source, buf)
  breadcrumbs.update(buf)
  local rendered = vim.api.nvim_eval_statusline(breadcrumbs.render(buf, 300), { maxwidth = 300 }).str
  assert(rendered:find(expected[name] .. " " .. name, 1, true), "Filename breadcrumb is missing its type icon: " .. name)
  assert(require("ui.statusline").context().icon == expected[name], "Filename-only statusline still uses a generic file icon")
end
vim.api.nvim_win_set_buf(source, original)
local menu = breadcrumbs.pick()
assert(vim.wait(2000, function() return #menu.items >= 6 end, 10), "Icon dropdown didn't load")
local labels = {}
for _, item in ipairs(menu.items) do labels[item.label] = true end
for name, icon in pairs(expected) do assert(labels[icon .. " " .. name], "Dropdown lacks the file-type icon for " .. name) end
assert(labels["󰉋 folder"], "Directory icon was replaced by a file icon")
menu:close()
package.loaded["nvim-web-devicons"] = nil
assert(icons.get("main.py") == icons.fallback and not package.loaded["nvim-web-devicons"], "Early rendering loaded an optional plugin")
package.loaded["nvim-web-devicons"] = devicons
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Breadcrumb icons: Markdown/Python/Go/unknown glyphs beside filenames and dropdown entries, folder glyphs and safe early-startup fallback passed"
