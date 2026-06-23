local options = {
    formatters_by_ft = {
        json = { "jq" },  -- or "prettier"
        jsonc = { "jq" }, -- for JSON with comments
        python = { "ruff_format", "ruff_fix" },
        go = { "goimports", "gofmt" },
        lua = { "stylua" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        rust = { "rustfmt" },
        c = { "clang_format" },
        cpp = { "clang_format" },
    },
    format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
    },
}

return options
