-- Lua language server settings for editing this config and ordinary Lua code.
return {
  Lua = {
    runtime = { version = "LuaJIT" },
    workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
    diagnostics = { globals = { "vim" } },
    telemetry = { enable = false },
  },
}
