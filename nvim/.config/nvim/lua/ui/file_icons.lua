-- Devicons needs both the filename and extension. Never lazy-load a plugin
-- from a statusline redraw; unknown types and early startup get a file glyph.
local M = { fallback = "󰈚" }
function M.get(path)
  local icons = package.loaded["nvim-web-devicons"]
  if not icons then return M.fallback end
  local name = vim.fs.basename(path)
  local extension = name:match("%.([^%.]+)$")
  return icons.get_icon(name, extension, { default = true }) or M.fallback
end
return M
