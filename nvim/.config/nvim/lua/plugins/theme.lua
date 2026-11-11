-- Only the startup provider is eager; every other theme loads on selection.
local loader = require "config.theme_loader"
local specs = {}
for _, entry in ipairs(require("themes.catalog").entries()) do
  if entry.plugin then
    local active = vim.tbl_contains(entry.schemes, loader.startup())
    specs[#specs + 1] = {
      entry.plugin,
      name = entry.name,
      lazy = not active,
      priority = 1000,
      config = function()
        if entry.module then
          local opts = type(entry.opts) == "function" and entry.opts() or entry.opts
          require(entry.module).setup(opts or {})
        end
        if active then
          if not loader.apply() then vim.cmd.colorscheme "habamax" end
        end
      end,
    }
  end
end
return specs
