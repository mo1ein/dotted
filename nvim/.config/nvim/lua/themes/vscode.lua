-- Data adapter for VS Code's bundled JSONC themes, include chains, and token rules.
-- TextMate scopes are mapped to Neovim roles, not executed as grammars.
local M = {}
local files = {}

local function read(path, loading)
  if files[path] then return files[path] end
  loading = loading or {}
  assert(not loading[path], "Cyclic VS Code theme include: " .. path)
  loading[path] = true
  local data = require("themes.jsonc").decode(table.concat(vim.fn.readfile(path), "\n"))
  local parent = { colors = {}, tokenColors = {}, semanticTokenColors = {} }
  if data.include then
    assert(data.include:match "^%./[%w_-]+%.json$", "Unsafe VS Code include path")
    parent = read(vim.fn.fnamemodify(path, ":h") .. "/" .. data.include:sub(3), loading)
  end
  local result = {
    colors = vim.tbl_extend("force", parent.colors or {}, data.colors or {}),
    tokenColors = vim.deepcopy(parent.tokenColors or {}),
    semanticTokenColors = vim.tbl_extend("force", parent.semanticTokenColors or {}, data.semanticTokenColors or {}),
  }
  for _, rule in ipairs(data.tokenColors or {}) do result.tokenColors[#result.tokenColors + 1] = rule end
  loading[path] = nil
  files[path] = result
  return result
end

local function token(rules, query)
  local matches = {}
  for order, rule in ipairs(rules) do
    local scopes = type(rule.scope) == "string" and { rule.scope } or rule.scope or {}
    for _, combined in ipairs(scopes) do
      for scope in combined:gmatch "[^,]+" do
        scope = vim.trim(scope)
        -- Stack/negation selectors require TextMate grammar context; don't
        -- incorrectly apply a language-specific nested selector to every token.
        if not scope:find "%s" and (query == scope or query:sub(1, #scope + 1) == scope .. ".") then
          matches[#matches + 1] = { specificity = #scope, order = order, attrs = rule.settings or {} }
        end
      end
    end
  end
  table.sort(matches, function(a, b)
    return a.specificity == b.specificity and a.order < b.order or a.specificity < b.specificity
  end)
  local attrs = {}
  for _, match in ipairs(matches) do attrs = vim.tbl_extend("force", attrs, match.attrs) end
  local result = { color = attrs.foreground }
  if type(attrs.fontStyle) == "string" then
    result.font_style = attrs.fontStyle:find("italic", 1, true) and "italic" or "normal"
    result.font_weight = attrs.fontStyle:find("bold", 1, true) and 700 or 400
    result.underline = attrs.fontStyle:find("underline", 1, true) ~= nil
    result.strikethrough = attrs.fontStyle:find("strikethrough", 1, true) ~= nil
  end
  return result
end

function M.convert(path, appearance, high_contrast)
  local data = read(path)
  local c, style = data.colors, {}
  local light = appearance == "light"
  for destination, source in pairs {
    ["editor.background"] = "editor.background", ["editor.foreground"] = "editor.foreground",
    ["text.muted"] = "descriptionForeground", ["text.accent"] = "textLink.foreground",
    ["elevated_surface.background"] = "editorWidget.background", border = "panel.border",
    ["border.variant"] = "editorIndentGuide.background1", ["panel.background"] = "sideBar.background",
    ["editor.active_line.background"] = "editor.lineHighlightBackground",
    ["editor.line_number"] = "editorLineNumber.foreground", ["editor.active_line_number"] = "editorLineNumber.activeForeground",
    ["editor.invisible"] = "editorWhitespace.foreground", ["editor.wrap_guide"] = "editorRuler.foreground",
    ["search.match_background"] = "editor.findMatchHighlightBackground", ["search.active_match_background"] = "editor.findMatchBackground",
    ["status_bar.background"] = "statusBar.background", ["tab.inactive_background"] = "tab.inactiveBackground",
    ["tab.active_background"] = "tab.activeBackground", ["tab_bar.background"] = "editorGroupHeader.tabsBackground",
    ["editor.document_highlight.read_background"] = "editor.wordHighlightBackground",
    ["editor.document_highlight.write_background"] = "editor.wordHighlightStrongBackground",
    ["version_control.added"] = "editorGutter.addedBackground", ["version_control.modified"] = "editorGutter.modifiedBackground",
    ["version_control.deleted"] = "editorGutter.deletedBackground", ["created.background"] = "diffEditor.insertedLineBackground",
    ["deleted.background"] = "diffEditor.removedLineBackground", ignored = "gitDecoration.ignoredResourceForeground",
    error = "errorForeground", warning = "editorWarning.foreground", info = "editorInfo.foreground", hint = "editorHint.foreground",
    ["terminal.background"] = "terminal.background", predictive = "editorGhostText.foreground",
  } do if type(c[source]) == "string" then style[destination] = c[source] end end
  style["editor.background"] = style["editor.background"] or (light and "#ffffff" or "#000000")
  style["editor.foreground"] = style["editor.foreground"] or c.foreground or (light and "#292929" or "#ffffff")
  style.players = { {
    cursor = c["editorCursor.foreground"] or style["editor.foreground"],
    selection = c["editor.selectionBackground"] or (high_contrast and (light and "#0f4a85" or "#ffffff") or nil),
    selection_foreground = c["editor.selectionForeground"] or (high_contrast and (light and "#ffffff" or "#000000") or nil),
  } }
  -- Official terminalColorRegistry.ts defaults from the same pinned VS Code tag.
  local defaults = light and {
    "#000000", "#cd3131", "#107c10", "#949800", "#0451a5", "#bc05bc", "#0598bc", "#555555",
    "#666666", "#f14c4c", "#14ce14", "#b5ba00", "#3b8eea", "#d670d6", "#29b8db", "#a5a5a5",
  } or {
    "#000000", "#cd3131", "#0dbc79", "#e5e510", "#2472c8", "#bc3fbc", "#11a8cd", "#e5e5e5",
    "#666666", "#f14c4c", "#23d18b", "#f5f543", "#3b8eea", "#d670d6", "#29b8db", "#e5e5e5",
  }
  if high_contrast then
    defaults = light and {
      "#292929", "#cd3131", "#136c13", "#949800", "#0451a5", "#bc05bc", "#0598bc", "#555555",
      "#666666", "#cd3131", "#00bc00", "#b5ba00", "#0451a5", "#bc05bc", "#0598bc", "#a5a5a5",
    } or {
      "#000000", "#cd0000", "#00cd00", "#cdcd00", "#0000ee", "#cd00cd", "#00cdcd", "#e5e5e5",
      "#7f7f7f", "#ff0000", "#00ff00", "#ffff00", "#5c5cff", "#ff00ff", "#00ffff", "#ffffff",
    }
  end
  for i, name in ipairs { "Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White" } do
    style["terminal.ansi." .. name:lower()] = c["terminal.ansi" .. name] or defaults[i]
    style["terminal.ansi.bright_" .. name:lower()] = c["terminal.ansiBright" .. name] or defaults[i + 8]
  end
  style.syntax = {}
  for role, scope in pairs {
    comment = "comment", ["comment.doc"] = "comment.block.documentation", attribute = "entity.other.attribute-name",
    boolean = "constant.language.boolean", constant = "constant", constructor = "entity.name.type",
    ["function"] = "entity.name.function", keyword = "keyword", label = "entity.name.label",
    link_text = "markup.underline.link", link_uri = "string.other.link", namespace = "entity.name.namespace",
    number = "constant.numeric", operator = "keyword.operator", preproc = "meta.preprocessor", property = "meta.property-name",
    punctuation = "punctuation", ["punctuation.bracket"] = "punctuation.section",
    ["punctuation.delimiter"] = "punctuation.separator", ["punctuation.list_marker"] = "punctuation.definition.list.begin.markdown",
    string = "string", ["string.escape"] = "constant.character.escape", ["string.regex"] = "string.regexp",
    ["string.special"] = "string.other", tag = "entity.name.tag", ["text.literal"] = "markup.inline.raw",
    title = "markup.heading", ["type"] = "entity.name.type", variable = "variable.other",
    ["variable.parameter"] = "variable.parameter.function", ["variable.special"] = "variable.language",
    variant = "variable.other.enummember", ["diff.plus"] = "markup.inserted", ["diff.minus"] = "markup.deleted",
    emphasis = "markup.italic", ["emphasis.strong"] = "markup.bold",
  } do style.syntax[role] = token(data.tokenColors, scope) end
  return { appearance = appearance, style = style }
end

return M
