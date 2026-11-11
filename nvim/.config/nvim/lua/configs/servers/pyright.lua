-- Python type analysis; Ruff handles import organization and lint rules.
return {
  pyright = { disableOrganizeImports = true },
  python = {
    analysis = {
      autoSearchPaths = true,
      useLibraryCodeForTypes = true,
      diagnosticMode = "workspace",
      typeCheckingMode = "basic",
      autoImportCompletions = true,
    },
  },
}
