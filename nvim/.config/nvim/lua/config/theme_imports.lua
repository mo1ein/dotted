-- Bundled Ghostty/Zed/VS Code data ships in the config, not fetched at startup.
return {
  ghostty = true,
  zed = true,
  vscode = true,
  cache_size = 16, -- bounded parsed-palette cache, including live previews
}
