-- Owned Neovim adapter for bundled Ghostty, Zed, and VS Code theme data.
-- Ghostty supplies ANSI colors only; its syntax mapping here is an adaptation.
local M = {}
local cache, order, families = {}, {}, {}

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end

local function mix(front, back, opacity)
  local r, g, b = rgb(front)
  local br, bg, bb = rgb(back)
  return ("#%02x%02x%02x"):format(
    math.floor(r * opacity + br * (1 - opacity) + 0.5),
    math.floor(g * opacity + bg * (1 - opacity) + 0.5),
    math.floor(b * opacity + bb * (1 - opacity) + 0.5))
end

local function color(value, background)
  if type(value) ~= "string" then return nil end
  local hex = value:match "^#?(%x+)$"
  if not hex then return nil end
  if #hex == 3 or #hex == 4 then hex = hex:gsub(".", "%0%0") end
  if #hex ~= 6 and #hex ~= 8 then return nil end
  local solid = "#" .. hex:sub(1, 6):lower()
  if #hex == 8 and hex:sub(7, 8):lower() ~= "ff" then
    return mix(solid, background or "#000000", tonumber(hex:sub(7, 8), 16) / 255)
  end
  return solid
end

local function brightness(hex)
  local r, g, b = rgb(hex)
  return r * 0.2126 + g * 0.7152 + b * 0.0722
end

function M.palette(scheme)
  if cache[scheme] then return cache[scheme] end
  local record = assert(require("themes.bundled_catalog").find(scheme), "Unknown bundled theme: " .. scheme)
  local p = { ansi = {}, style = {}, syntax = {} }
  if record.source == "ghostty" then
    local settings = {}
    for _, line in ipairs(vim.fn.readfile(record.path)) do
      local key, value = line:match "^%s*([%w-]+)%s*=%s*(.-)%s*$"
      if key == "palette" then
        local index, hex = value:match "^(%d+)%s*=%s*(#?%x+)"
        if index and tonumber(index) < 16 then p.ansi[tonumber(index) + 1] = color(hex) end
      elseif key then settings[key] = value end
    end
    p.bg = assert(color(settings.background), "Invalid Ghostty background: " .. record.name)
    p.fg = assert(color(settings.foreground), "Invalid Ghostty foreground: " .. record.name)
    p.cursor = color(settings["cursor-color"]) or p.fg
    p.cursor_text = color(settings["cursor-text"]) or p.bg
    p.selection = color(settings["selection-background"]) or mix(p.fg, p.bg, 0.2)
    p.selection_fg = color(settings["selection-foreground"]) or p.fg
    p.appearance = brightness(p.bg) > brightness(p.fg) and "light" or "dark"
  else
    local source
    if record.source == "vscode" then
      source = require("themes.vscode").convert(record.path, record.appearance, record.high_contrast)
    else
      if not families[record.path] then
        families[record.path] = vim.json.decode(table.concat(vim.fn.readfile(record.path), "\n"))
      end
      for _, theme in ipairs(families[record.path].themes) do if theme.name == record.name then source = theme; break end end
      assert(source, "Zed variant missing: " .. record.name)
    end
    p.style, p.syntax, p.appearance = source.style, source.style.syntax or {}, source.appearance
    p.bg = assert(color(p.style["editor.background"]), "Invalid Zed editor background")
    p.fg = assert(color(p.style["editor.foreground"], p.bg), "Invalid Zed editor foreground")
    local ansi = { "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white" }
    for i, name in ipairs(ansi) do
      p.ansi[i] = color(p.style["terminal.ansi." .. name], p.bg)
      p.ansi[i + 8] = color(p.style["terminal.ansi.bright_" .. name], p.bg)
    end
    local player = p.style.players and p.style.players[1] or {}
    p.cursor = color(player.cursor, p.bg) or p.fg
    p.cursor_text = p.bg
    p.selection = color(player.selection, p.bg) or mix(p.fg, p.bg, 0.2)
    p.selection_fg = color(player.selection_foreground, p.bg) or p.fg
  end
  for i = 1, 16 do assert(p.ansi[i], record.name .. " is missing ANSI color " .. (i - 1)) end
  cache[scheme] = p
  order[#order + 1] = scheme
  if #order > math.max(1, require("config.theme_imports").cache_size or 16) then cache[table.remove(order, 1)] = nil end
  return p
end

function M.highlights(p, opts)
  opts = opts or require "config.theme_imports"
  local function ui(key, fallback) return color(p.style[key], p.bg) or fallback end
  local a, fg, bg = p.ansi, p.fg, p.bg
  local muted = ui("text.muted", mix(fg, bg, 0.5))
  local surface = ui("elevated_surface.background", mix(fg, bg, 0.06))
  local accent = ui("text.accent", a[5])
  local green, red, yellow = ui("created", a[3]), ui("error", a[2]), ui("warning", a[4])
  local normal_bg = opts.transparent and "NONE" or bg
  local groups = {
    Normal = { fg = fg, bg = normal_bg }, NormalNC = { fg = fg, bg = normal_bg },
    NormalFloat = { fg = fg, bg = opts.transparent and "NONE" or surface },
    FloatBorder = { fg = ui("border", muted) }, FloatTitle = { fg = accent, bold = true },
    Cursor = { fg = p.cursor_text, bg = p.cursor }, TermCursor = { fg = p.cursor_text, bg = p.cursor },
    Visual = { bg = p.selection, fg = p.selection_fg },
    CursorLine = { bg = ui("editor.active_line.background", surface) },
    CursorColumn = { bg = surface }, ColorColumn = { bg = ui("editor.wrap_guide", surface) },
    LineNr = { fg = ui("editor.line_number", muted), bg = normal_bg },
    CursorLineNr = { fg = ui("editor.active_line_number", accent), bold = true },
    SignColumn = { bg = normal_bg }, NonText = { fg = ui("editor.invisible", muted) },
    EndOfBuffer = { fg = bg }, WinSeparator = { fg = ui("border", muted) },
    Folded = { fg = muted, bg = surface }, FoldColumn = { fg = muted, bg = normal_bg },
    StatusLine = { fg = fg, bg = ui("status_bar.background", surface) },
    StatusLineNC = { fg = muted, bg = ui("status_bar.background", surface) },
    TabLine = { fg = muted, bg = ui("tab.inactive_background", surface) },
    TabLineSel = { fg = accent, bg = ui("tab.active_background", bg), bold = true },
    TabLineFill = { bg = ui("tab_bar.background", surface) },
    Search = { bg = ui("search.match_background", mix(a[4], bg, 0.35)) },
    IncSearch = { bg = ui("search.active_match_background", a[4]), fg = bg },
    MatchParen = { fg = accent, bg = surface, bold = true },
    Pmenu = { fg = fg, bg = surface }, PmenuSel = { fg = bg, bg = accent },
    PmenuSbar = { bg = surface }, PmenuThumb = { bg = muted },
    Directory = { fg = accent }, ErrorMsg = { fg = red }, WarningMsg = { fg = yellow },
    DiagnosticError = { fg = red }, DiagnosticWarn = { fg = yellow },
    DiagnosticInfo = { fg = ui("info", a[5]) }, DiagnosticHint = { fg = ui("hint", a[7]) },
    DiagnosticOk = { fg = ui("success", green) },
    LspReferenceRead = { bg = ui("editor.document_highlight.read_background", surface) },
    LspReferenceWrite = { bg = ui("editor.document_highlight.write_background", surface) },
    LspReferenceText = { bg = surface },
    LspInlayHint = { fg = ui("predictive", muted), bg = surface },
    DiffAdd = { bg = ui("created.background", mix(green, bg, 0.18)) },
    DiffChange = { bg = ui("modified.background", mix(yellow, bg, 0.18)) },
    DiffDelete = { bg = ui("deleted.background", mix(red, bg, 0.18)) },
    DiffText = { bg = mix(accent, bg, 0.3) },
    Added = { fg = green }, Removed = { fg = red }, Changed = { fg = yellow },
    GitSignsAdd = { fg = ui("version_control.added", green) },
    GitSignsChange = { fg = ui("version_control.modified", yellow) },
    GitSignsDelete = { fg = ui("version_control.deleted", red) },
    NvimTreeNormal = { fg = fg, bg = opts.transparent and "NONE" or ui("panel.background", bg) },
    NvimTreeNormalNC = { link = "NvimTreeNormal" }, NvimTreeFolderName = { fg = accent },
    NvimTreeFolderIcon = { fg = accent }, NvimTreeRootFolder = { fg = accent, bold = true },
    NvimTreeGitIgnored = { fg = ui("ignored", muted) },
    IblIndent = { fg = ui("border.variant", surface) }, IblChar = { fg = ui("border.variant", surface) },
    IblScope = { fg = muted }, IblScopeChar = { fg = muted },
    WhichKey = { fg = accent }, WhichKeyGroup = { fg = green }, WhichKeyDesc = { fg = fg },
    WhichKeySeparator = { fg = muted },
    CmpItemAbbr = { fg = fg }, CmpItemAbbrMatch = { fg = accent, bold = true },
    CmpItemAbbrDeprecated = { fg = muted, strikethrough = true }, CmpItemMenu = { fg = muted },
    MasonHeader = { fg = bg, bg = accent }, MasonHighlight = { fg = accent }, MasonMuted = { fg = muted },
  }
  local fallback = {
    comment = muted, ["comment.doc"] = muted, attribute = a[4], boolean = a[4], constant = a[4],
    constructor = a[5], embedded = fg, emphasis = fg, ["emphasis.strong"] = fg,
    enum = a[7], ["function"] = a[5], keyword = a[6], label = a[4], link_text = a[5], link_uri = a[7],
    namespace = a[7], number = a[4], operator = a[7], preproc = a[6], property = fg,
    punctuation = fg, ["punctuation.bracket"] = fg, ["punctuation.delimiter"] = fg,
    ["punctuation.list_marker"] = a[2], ["punctuation.markup"] = a[2], ["punctuation.special"] = a[7],
    selector = a[4], ["selector.pseudo"] = a[6], string = a[3], ["string.escape"] = a[7],
    ["string.regex"] = a[4], ["string.special"] = a[4], ["string.special.symbol"] = a[4],
    tag = a[2], ["text.literal"] = a[3], title = a[5], ["type"] = a[7], variable = fg,
    ["variable.parameter"] = a[2], ["variable.special"] = a[4], variant = a[5],
    ["diff.plus"] = green, ["diff.minus"] = red,
  }
  local roles = {
    comment = { "Comment", "@comment" }, ["comment.doc"] = { "@comment.documentation" },
    attribute = { "@attribute" }, boolean = { "Boolean", "@boolean" }, constant = { "Constant", "@constant" },
    constructor = { "@constructor" }, embedded = { "@markup.raw" }, emphasis = { "@markup.italic" },
    ["emphasis.strong"] = { "@markup.strong" }, enum = { "@type.enum" },
    ["function"] = { "Function", "@function", "@function.call", "@function.method", "@function.method.call" },
    keyword = { "Keyword", "Statement", "Conditional", "Repeat", "Exception", "StorageClass", "@keyword" },
    label = { "Label", "@label" }, link_text = { "@markup.link.label" }, link_uri = { "@markup.link.url" },
    namespace = { "Include", "@module" }, number = { "Number", "Float", "@number", "@number.float" },
    operator = { "Operator", "@operator" }, preproc = { "PreProc", "Define", "@keyword.directive" },
    property = { "Identifier", "@property", "@variable.member" }, punctuation = { "Delimiter", "@punctuation" },
    ["punctuation.bracket"] = { "@punctuation.bracket" }, ["punctuation.delimiter"] = { "@punctuation.delimiter" },
    ["punctuation.list_marker"] = { "@markup.list" }, ["punctuation.markup"] = { "@markup" },
    ["punctuation.special"] = { "@punctuation.special" }, selector = { "@tag.attribute" },
    ["selector.pseudo"] = { "@attribute.builtin" }, string = { "String", "@string" },
    ["string.escape"] = { "SpecialChar", "@string.escape" }, ["string.regex"] = { "@string.regexp" },
    ["string.special"] = { "@string.special" }, ["string.special.symbol"] = { "@string.special.symbol" },
    tag = { "Tag", "@tag" }, ["text.literal"] = { "@markup.raw.block" }, title = { "Title", "@markup.heading" },
    ["type"] = { "Type", "Typedef", "Structure", "@type", "@type.builtin" }, variable = { "@variable" },
    ["variable.parameter"] = { "@variable.parameter" }, ["variable.special"] = { "Special", "@variable.builtin" },
    variant = { "@constant.builtin" }, ["diff.plus"] = { "@diff.plus" }, ["diff.minus"] = { "@diff.minus" },
  }
  for role, targets in pairs(roles) do
    local source = p.syntax[role]
    if type(source) ~= "table" then source = {} end
    local attrs = { fg = color(source.color, bg) or fallback[role] or fg }
    if type(source.font_weight) == "number" then attrs.bold = source.font_weight >= 600 end
    if type(source.font_style) == "string" then attrs.italic = source.font_style == "italic" end
    if type(source.underline) == "boolean" then attrs.underline = source.underline end
    if type(source.strikethrough) == "boolean" then attrs.strikethrough = source.strikethrough end
    if role == "link_uri" then attrs.underline = true end
    if role == "emphasis" and attrs.italic == nil then attrs.italic = true end
    if role == "emphasis.strong" and attrs.bold == nil then attrs.bold = true end
    for _, target in ipairs(targets) do groups[target] = attrs end
  end
  for semantic, target in pairs {
    class = "@type", enum = "@type", interface = "@type", struct = "@type", type = "@type",
    function_ = "@function", method = "@function.method", property = "@property", variable = "@variable",
    parameter = "@variable.parameter", namespace = "@module", enumMember = "@constant", keyword = "@keyword",
  } do
    groups["@lsp.type." .. semantic:gsub("_$", "")] = { link = target }
  end
  return groups
end

function M.load(scheme, opts, background)
  local palette = M.palette(scheme)
  vim.g.colors_name = nil
  vim.o.background = background or palette.appearance
  vim.o.termguicolors = true
  vim.cmd "highlight clear"
  if vim.g.syntax_on then vim.cmd "syntax reset" end
  vim.g.colors_name = scheme
  for name, attrs in pairs(M.highlights(palette, opts)) do vim.api.nvim_set_hl(0, name, attrs) end
  for i, value in ipairs(palette.ansi) do vim.g["terminal_color_" .. (i - 1)] = value end
end

function M.cache_info()
  return { palettes = vim.tbl_count(cache), families = vim.tbl_count(families) }
end

return M
