-- Original transparent-mode changes, restricted to the integrations we use.
local c = require("themes.onedark.palette").ui
local groups = {
  NvimTreeWinSeparator = { fg = c.one_bg2, bg = "NONE" },
  CmpDocBorder = { bg = "none", fg = c.grey },
}
for _, name in ipairs {
  "NormalFloat", "Normal", "Folded", "NvimTreeNormal", "NvimTreeNormalNC",
  "NvimTreeCursorLine", "CursorLine", "Pmenu", "CmpPmenu", "CmpDoc", "WinBar", "WinBarNC",
} do
  groups[name] = { bg = "NONE" }
end
for i = 1, 7 do
  -- These replace (not merge) the opaque scope highlights upstream.
  groups["@ibl.scope.underline." .. i] = { underline = true }
end
return groups
