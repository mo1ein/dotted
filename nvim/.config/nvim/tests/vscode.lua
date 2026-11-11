-- Offline VS Code source/JSONC regression tests, including the real Dark 2026.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local jsonc = require "themes.jsonc"
local data = jsonc.decode([[{
  // not a data field
  "url": "https://example.org/path//value", /* ignored */
  "quote": "a\"//b",
  "items": [1, 2,],
}]])
assert(data.url == "https://example.org/path//value" and data.quote == 'a"//b' and #data.items == 2)
local renderer = require "themes.bundled"
local p = renderer.palette "vscode-dark-2026"
assert(p.bg == "#121314" and p.fg == "#bbbebf", "Dark 2026 was replaced with another VS Code palette")
local groups = renderer.highlights(p)
for group, color in pairs { Function = "#d2a8ff", Comment = "#8b949e", Keyword = "#ff7b72", String = "#a5d6ff" } do
  assert(groups[group].fg == color, "Wrong Dark 2026 token color for " .. group)
end
assert(p.style["status_bar.background"] == "#191A1B")
assert(renderer.palette("vscode-dark-modern").bg == "#1f1f1f")
assert(renderer.palette("vscode-dark").bg == "#1e1e1e")
assert(renderer.palette("vscode-high-contrast-dark").bg == "#000000")
for _, scheme in ipairs { "vscode-light", "vscode-light-plus", "vscode-light-modern", "vscode-light-2026", "vscode-high-contrast-light" } do
  assert(renderer.palette(scheme).appearance == "light", scheme .. " didn't retain its light appearance")
end
for _, scheme in ipairs { "vscode-high-contrast-dark", "vscode-high-contrast-light" } do
  local selection = renderer.highlights(renderer.palette(scheme)).Visual
  assert(require("ui.color").contrast(tonumber(selection.fg:sub(2), 16), tonumber(selection.bg:sub(2), 16)) >= 4.5)
end
assert(vim.v.errmsg == "", vim.v.errmsg)
print "VS Code: JSONC, inheritance, all 10 variants, and official Dark 2026 UI/token colors passed"
