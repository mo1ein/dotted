-- Original default statusline highlight data, renamed; MIT notices in licenses/.
local c = require("themes.onedark.palette").ui
return function(transparent)
  local bg = transparent and "NONE" or c.statusline_bg
  local groups = {
    StatusLine = { bg = bg },
    StatusLineNC = { bg = transparent and "NONE" or c.darker_black },
    DottedSt_gitIcons = { fg = "#83878f", bg = bg, bold = true },
    DottedSt_Lsp = { fg = c.nord_blue, bg = bg },
    DottedSt_LspMsg = { fg = c.green, bg = bg },
    DottedSt_EmptySpace = { fg = c.grey, bg = c.lightbg },
    DottedSt_file = { bg = c.lightbg, fg = c.white },
    DottedSt_file_sep = { bg = bg, fg = c.lightbg },
    DottedSt_cwd_icon = { fg = c.one_bg, bg = c.red },
    DottedSt_cwd_text = { fg = c.white, bg = c.lightbg },
    DottedSt_cwd_sep = { fg = c.red, bg = bg },
    DottedSt_pos_sep = { fg = c.green, bg = c.lightbg },
    DottedSt_pos_icon = { fg = c.black, bg = c.green },
    DottedSt_pos_text = { fg = c.green, bg = c.lightbg },
    DottedSt_lspError = { fg = c.red, bg = bg },
    DottedSt_lspWarning = { fg = c.yellow, bg = bg },
    DottedSt_LspHints = { fg = c.purple, bg = bg },
    DottedSt_LspInfo = { fg = c.green, bg = bg },
  }
  for mode, accent in pairs {
    Normal = c.nord_blue, Visual = c.cyan, Insert = c.dark_purple, Terminal = c.green,
    NTerminal = c.yellow, Replace = c.orange, Confirm = c.teal, Command = c.green, Select = c.blue,
  } do
    groups["DottedSt_" .. mode .. "Mode"] = { fg = c.black, bg = accent, bold = true }
    groups["DottedSt_" .. mode .. "ModeSep"] = { fg = accent, bg = c.grey }
  end
  return groups
end
