-- Owned statusline layout: the former default layout, editable without a plugin.
return {
  order = { "mode", "file", "git", "align", "progress", "align", "diagnostics", "lsp", "cwd", "tools", "cursor" },
  separators = { left = "", right = "" },
}
