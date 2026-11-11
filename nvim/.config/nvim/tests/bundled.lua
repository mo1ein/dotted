-- Offline bundle validation: all source palettes, ANSI colors, styles, cache bound.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local catalog = require "themes.bundled_catalog"
local renderer = require "themes.bundled"
local counts = {}
for _, provider in ipairs(catalog.entries()) do
  counts[provider.source] = #provider.schemes
  for _, scheme in ipairs(provider.schemes) do
    local p = renderer.palette(scheme)
    assert(p.bg:match "^#%x%x%x%x%x%x$" and p.fg:match "^#%x%x%x%x%x%x$")
    assert(#p.ansi == 16 and (p.appearance == "dark" or p.appearance == "light"))
    local groups = renderer.highlights(p)
    assert(groups.Normal.bg == p.bg and groups.Normal.fg == p.fg)
    assert(renderer.cache_info().palettes <= require("config.theme_imports").cache_size)
  end
end
assert(counts.ghostty == 819 and counts.zed == 11 and counts.vscode == 10, "Bundled snapshot is incomplete")
renderer.load("zed-one-dark")
local p = renderer.palette("zed-one-dark")
assert(vim.api.nvim_get_hl(0, { name = "Function", link = false }).fg == tonumber(p.syntax["function"].color:sub(2, 7), 16))
assert(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == tonumber(p.bg:sub(2), 16))
for i, value in ipairs(p.ansi) do assert(vim.g["terminal_color_" .. (i - 1)] == value) end
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Bundled: all 819 Ghostty + 11 Zed + 10 VS Code palettes, styles, ANSI colors, and bounded cache passed"
