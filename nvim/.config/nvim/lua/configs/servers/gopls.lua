-- Go analysis and formatting preferences; server roots use lspconfig defaults.
return {
  gopls = { analyses = { unusedparams = true }, staticcheck = true, gofumpt = true },
}
