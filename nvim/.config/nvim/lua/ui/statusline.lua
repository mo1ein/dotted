-- Native statusline recreating the former default UI; no distribution renderer.
local M = { progress = {} }
local layout = require "config.statusline"

local function text(value)
  return tostring(value or ""):gsub("[\r\n]", " "):gsub("%%", "%%%%")
end

local function hl(role)
  return "%#DottedSt_" .. role .. "#"
end

-- Labels follow Neovim's mode() values. Unknown/new modes safely use NORMAL.
function M.mode(mode)
  local initial = mode:sub(1, 1)
  if initial == "n" then
    if mode:sub(1, 2) == "nt" then return mode == "ntT" and "NTERMINAL (ntT)" or "NTERMINAL", "NTerminal" end
    if mode:sub(1, 2) == "ni" then return "NORMAL " .. mode:sub(3):lower(), "Normal" end
    return ({ no = "NORMAL (no)", nov = "NORMAL (nov)", noV = "NORMAL (noV)" })[mode] or "NORMAL", "Normal"
  end
  if initial == "i" then return "INSERT", "Insert" end
  if initial == "R" then
    local labels = { Rc = "REPLACE (Rc)", Rx = "REPLACEa (Rx)", Rvc = "V-REPLACE (Rvc)", Rvx = "V-REPLACE (Rvx)" }
    return labels[mode] or (mode == "Rv" and "V-REPLACE" or "REPLACE"), "Replace"
  end
  if initial == "c" then return "COMMAND", "Command" end
  if initial == "r" or mode == "x" then
    return ({ r = "PROMPT", rm = "MORE" })[mode] or "CONFIRM", "Confirm"
  end
  if mode == "t" or mode == "!" then return mode == "!" and "SHELL" or "TERMINAL", "Terminal" end
  if initial == "s" or mode == "S" or mode == "\19" then
    return mode == "S" and "S-LINE" or (mode == "\19" and "S-BLOCK" or "SELECT"), "Select"
  end
  if initial == "v" or initial == "V" or mode == "\22" then
    return ({ vs = "V-CHAR (Ctrl O)", V = "V-LINE", Vs = "V-LINE", ["\22"] = "V-BLOCK" })[mode] or "VISUAL", "Visual"
  end
  return "NORMAL", "Normal"
end

function M.context()
  local win = tonumber(vim.g.statusline_winid) or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then win = vim.api.nvim_get_current_win() end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" then
    local source = require("ui.buffers").source_win()
    if source then buf = vim.api.nvim_win_get_buf(source) end
  end
  local path = vim.api.nvim_buf_get_name(buf)
  local filename = path == "" and "Empty" or vim.fn.fnamemodify(path, ":t")
  local icon = require("ui.file_icons").get(filename)
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do names[#names + 1] = client.name end
  local messages = {}
  for _, key in ipairs(vim.fn.sort(vim.tbl_keys(M.progress))) do messages[#messages + 1] = M.progress[key] end
  local cwd = vim.fn.getcwd(vim.fn.win_id2win(win))
  return {
    active = win == vim.api.nvim_get_current_win(), mode = vim.api.nvim_get_mode().mode,
    filename = filename, icon = icon, width = vim.o.columns, bufnr = buf,
    git = vim.b[buf].gitsigns_head and vim.b[buf].gitsigns_status_dict or nil,
    diagnostics = vim.diagnostic.count(buf), clients = names,
    cwd = vim.fn.fnamemodify(cwd, ":t"), progress = messages[#messages] or "",
  }
end

local sections = {}
function sections.mode(ctx)
  if not ctx.active then return "" end
  local label, role = M.mode(ctx.mode)
  return hl(role .. "Mode") .. "  " .. label .. hl(role .. "ModeSep") .. layout.separators.right
    .. hl("EmptySpace") .. layout.separators.right
end
function sections.file(ctx)
  local breadcrumbs = require("config.ui").breadcrumbs and ctx.bufnr and require("ui.breadcrumbs").render(ctx.bufnr, ctx.width)
  local icon = breadcrumbs and "󰉋" or ctx.icon
  return hl("file") .. " " .. text(icon) .. " " .. (breadcrumbs or text(ctx.filename)) .. " " .. hl("file_sep") .. layout.separators.right
end
function sections.git(ctx)
  local value = ""
  if ctx.git then
    value = "  " .. text(ctx.git.head)
    for _, item in ipairs { { "added", "  " }, { "changed", "  " }, { "removed", "  " } } do
      local count = ctx.git[item[1]] or 0
      if count > 0 then value = value .. item[2] .. count end
    end
  end
  return hl("gitIcons") .. value
end
function sections.align() return "%=" end
function sections.progress(ctx) return hl("LspMsg") .. (ctx.width >= 120 and text(ctx.progress) or "") end
function sections.diagnostics(ctx)
  local result = { " " }
  for _, item in ipairs {
    { vim.diagnostic.severity.ERROR, "lspError", " " },
    { vim.diagnostic.severity.WARN, "lspWarning", " " },
    { vim.diagnostic.severity.HINT, "LspHints", "󰛩 " },
    { vim.diagnostic.severity.INFO, "LspInfo", "󰋼 " },
  } do
    local count = ctx.diagnostics[item[1]] or 0
    if count > 0 then result[#result + 1] = hl(item[2]) .. item[3] .. count .. " " end
  end
  return table.concat(result)
end
function sections.lsp(ctx)
  local label = ""
  if #ctx.clients > 0 then label = ctx.width > 100 and "   LSP ~ " .. text(ctx.clients[1]) .. " " or "   LSP " end
  return hl("Lsp") .. label
end
function sections.cwd(ctx)
  if ctx.width <= 85 then return "" end
  return hl("cwd_sep") .. layout.separators.left .. hl("cwd_icon") .. "󰉋 "
    .. hl("cwd_text") .. " " .. text(ctx.cwd) .. " "
end
function sections.cursor()
  return hl("pos_sep") .. layout.separators.left .. hl("pos_icon") .. " " .. hl("pos_text") .. " %l/%v "
end
function sections.tools()
  if not require("config.ui").tools.enabled then return "" end
  local group = require("ui.statusline_hover").tools() and "DottedStatuslineToolsHover" or "DottedStatuslineTools"
  return "%#" .. group .. "#%0@v:lua.DottedToolsToggle@ 󰒓 Tools %X"
end

function M.render(context)
  local ctx, result = context or M.context(), {}
  for _, name in ipairs(layout.order) do result[#result + 1] = sections[name](ctx) end
  return table.concat(result)
end

function M.setup()
  require("ui.statusline_hover").setup()
  local group = vim.api.nvim_create_augroup("OwnedStatusline", { clear = true })
  vim.o.laststatus = 3
  vim.o.statusline = "%!v:lua.require('ui.statusline').render()"
  require("ui.statusline_colors").apply()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group, callback = function() require("ui.statusline_colors").apply() end,
  })
  vim.api.nvim_create_autocmd({ "DiagnosticChanged", "LspAttach", "LspDetach" }, {
    group = group, callback = function() vim.cmd.redrawstatus() end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group, pattern = "GitSignsUpdate", callback = function() vim.cmd.redrawstatus() end,
  })
  vim.api.nvim_create_autocmd("LspProgress", {
    group = group,
    callback = function(args)
      local params = args.data and args.data.params
      if not params or type(params.value) ~= "table" then return end
      local value = params.value
      local key = tostring(args.data.client_id) .. ":" .. tostring(params.token)
      if value.kind == "end" then
        M.progress[key] = nil
      else
        local prefix = ""
        if value.percentage then
          local frames = { "", "󰪞", "󰪟", "󰪠", "󰪡", "󰪢", "󰪣", "󰪤", "󰪥", "" }
          local index = math.max(1, math.min(#frames, math.floor(value.percentage / 10)))
          prefix = frames[index] .. " " .. value.percentage .. "% "
        end
        M.progress[key] = prefix .. (value.title or "") .. " " .. ((value.message or ""):match "^(%d+/%d+)" or "")
      end
      vim.cmd.redrawstatus()
    end,
  })
end

return M
