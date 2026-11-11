-- Integration: all four severities use the former icons, never E/W/H/I letters.
require("lazy").load { plugins = { "nvim-lspconfig" } }
local severity = vim.diagnostic.severity
local expected = { [severity.ERROR] = "󰅙", [severity.WARN] = "", [severity.INFO] = "󰋼", [severity.HINT] = "󰌵" }
assert(vim.deep_equal(vim.diagnostic.config().signs.text, expected))
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "error", "warning", "info", "hint" })
local ns = vim.api.nvim_create_namespace "DiagnosticGutterRegression"
vim.diagnostic.set(ns, buf, {
  { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = "Test error" },
  { lnum = 1, col = 0, severity = severity.WARN, message = "Test warning" },
  { lnum = 2, col = 0, severity = severity.INFO, message = "Test info" },
  { lnum = 3, col = 0, severity = severity.HINT, message = "Test hint" },
})
vim.wait(100)
assert(#vim.diagnostic.get(buf) == 4, "Diagnostic data was lost")
local icons, count = {}, 0
for _, icon in pairs(expected) do icons[icon] = true end
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
  if mark[4].sign_text then
    assert(icons[vim.trim(mark[4].sign_text)], "Unexpected diagnostic gutter text")
    count = count + 1
  end
end
assert(count == 4, "Not all diagnostic icons rendered")
assert(vim.diagnostic.config().underline and vim.diagnostic.config().virtual_text)
vim.diagnostic.reset(ns, buf)
vim.api.nvim_buf_delete(buf, { force = true })
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Diagnostics: all four original gutter icons rendered; inline messages and underlines preserved"
vim.cmd "qa!"
