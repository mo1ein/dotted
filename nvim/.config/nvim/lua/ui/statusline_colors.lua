-- Adapt the original segmented UI to any theme with readable, filled badges.
-- OneDark keeps its exact vendored definitions. All other palettes use the same
-- role/transition geometry instead of flattening every section into one color.
local M = {}
local colors = require "ui.color"

function M.apply()
  if vim.g.colors_name == "dotted-onedark" then return end
  local normal, floating, status = colors.get "Normal", colors.get "NormalFloat", colors.get "StatusLine"
  local light = vim.o.background == "light"
  local canvas = normal.bg or floating.bg or status.bg or (light and 0xfafafa or 0x1e222a)
  local fg = colors.readable(normal.fg or status.fg or (light and 0x202020 or 0xd0d0d0), canvas)
  local panel = colors.mix(fg, canvas, 0.07)
  local transition = colors.mix(fg, canvas, 0.16)
  local center = require("config.transparency").enabled and "NONE" or canvas
  local function accent(group)
    return colors.readable(colors.get(group).fg or fg, canvas, 2)
  end
  local function define(role, attrs) vim.api.nvim_set_hl(0, "DottedSt_" .. role, attrs) end
  local green, red = accent "String", accent "DiagnosticError"
  local groups = {
    gitIcons = { fg = colors.readable(colors.get("Comment").fg or fg, canvas), bg = center, bold = true },
    Lsp = { fg = colors.readable(accent "Function", canvas), bg = center },
    LspMsg = { fg = colors.readable(green, canvas), bg = center },
    EmptySpace = { fg = transition, bg = panel },
    file = { fg = colors.readable(fg, panel), bg = panel },
    file_sep = { fg = panel, bg = center },
    cwd_icon = { fg = colors.text_on(red), bg = red },
    cwd_text = { fg = colors.readable(fg, panel), bg = panel },
    cwd_sep = { fg = red, bg = center },
    pos_sep = { fg = green, bg = panel },
    pos_icon = { fg = colors.text_on(green), bg = green },
    pos_text = { fg = colors.readable(green, panel), bg = panel },
  }
  for role, attrs in pairs(groups) do define(role, attrs) end
  for role, source in pairs {
    lspError = "DiagnosticError", lspWarning = "DiagnosticWarn", LspHints = "DiagnosticHint", LspInfo = "DiagnosticInfo",
  } do define(role, { fg = colors.readable(accent(source), canvas), bg = center }) end
  for mode, source in pairs {
    Normal = "Function", Insert = "Keyword", Visual = "Type", Replace = "DiagnosticWarn",
    Command = "String", Select = "Identifier", Terminal = "String", NTerminal = "DiagnosticWarn", Confirm = "Special",
  } do
    local color = accent(source)
    define(mode .. "Mode", { fg = colors.text_on(color), bg = color, bold = true })
    define(mode .. "ModeSep", { fg = color, bg = transition })
  end
  -- Some schemes use reverse/standout StatusLine attributes. Explicitly defining
  -- the canvas prevents these from turning transparent sections into solid bars.
  vim.api.nvim_set_hl(0, "StatusLine", { fg = fg, bg = center })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = fg, bg = center })
end

return M
