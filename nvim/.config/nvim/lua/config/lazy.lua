-- Bootstrap lazy.nvim; plugin files declare their own loading triggers.
local M = {}

function M.setup()
  local path = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
  if not vim.uv.fs_stat(path) then
    local output = vim.fn.system {
      "git", "clone", "--filter=blob:none", "--branch=stable",
      "https://github.com/folke/lazy.nvim.git", path,
    }
    if vim.v.shell_error ~= 0 then
      error("Unable to install lazy.nvim. Check Git/network access:\n" .. output)
    end
  end
  vim.opt.rtp:prepend(path)
  require("lazy").setup({ { import = "plugins" } }, {
    defaults = { lazy = false },
    -- Plugins ship their Lua runtime; avoid unnecessary LuaRocks bootstraps.
    rocks = { enabled = false },
    install = { colorscheme = { "habamax" } },
    checker = { enabled = false },
    change_detection = { notify = false },
    -- Keep built-in syntax, ftplugins, archive readers, etc. available.
  })
  -- lazy.nvim normalizes runtimepath during startup; add completion entries after.
  require("themes.catalog").index()
end

return M
