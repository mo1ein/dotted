-- Parser management uses the current API; highlighting is native Neovim.
local M = {}

function M.setup()
  require("nvim-treesitter").setup {}
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
    callback = function(args)
      -- Missing parsers are normal until :TSInstall; keep built-in syntax then.
      pcall(vim.treesitter.start, args.buf)
    end,
  })
end

return M
