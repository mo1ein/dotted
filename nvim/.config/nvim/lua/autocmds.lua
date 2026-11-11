-- Editor-only events; no plugin loading or theme/highlight work here.
local M = {}

function M.setup()
  local group = vim.api.nvim_create_augroup("UserEditor", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      if vim.fn.argc() ~= 1 or vim.fn.isdirectory(vim.fn.argv(0)) ~= 1 then return end
      local buf = vim.api.nvim_get_current_buf()
      if vim.bo[buf].modified or vim.bo[buf].buftype ~= ""
        or vim.fn.isdirectory(vim.api.nvim_buf_get_name(buf)) ~= 1 then return end
      vim.api.nvim_set_current_dir(vim.fn.fnamemodify(vim.fn.argv(0), ":p"))
      vim.cmd.enew()
      if vim.api.nvim_buf_is_valid(buf) and buf ~= vim.api.nvim_get_current_buf() then
        vim.api.nvim_buf_delete(buf, {})
      end
    end,
  })
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = group,
    callback = function() vim.hl.on_yank { timeout = 150 } end,
  })
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function()
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
    end,
  })
end

return M
