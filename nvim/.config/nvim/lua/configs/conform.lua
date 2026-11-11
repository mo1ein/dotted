-- Formatting policy only; missing external formatters fall back to LSP.
local options = {
    formatters_by_ft = {
        json = { "jq" },  -- or "prettier"
        jsonc = { "prettier" }, -- jq cannot parse JSON with comments
        python = { "ruff_fix", "ruff_format" },
        go = { "goimports", "gofmt" },
        lua = { "stylua" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        rust = { "rustfmt" },
        c = { "clang_format" },
        cpp = { "clang_format" },
    },
    format_on_save = function(buf)
        if vim.b[buf].dotted_launch_save then return nil end
        return { timeout_ms = 1000, lsp_format = "fallback" }
    end,
}

return options
