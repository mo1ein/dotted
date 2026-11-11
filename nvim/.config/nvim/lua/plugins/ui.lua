-- Independent UI plugins; none owns the editor's colorscheme.
return {
  { "nvim-tree/nvim-web-devicons", lazy = false, opts = {} },
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function() return require "configs.nvimtree" end,
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = function()
      return {
        spec = require("keymaps").which_key_groups(),
        -- These panels own their local keys. Which-key's eager `g` trigger can
        -- otherwise shadow mappings added after an async provider mounts.
        disable = {
          ft = { "dotted_tools", "dotted_problems", "dotted_menu", "dotted_switcher", "trouble", "dapui_console", "OverseerOutput" },
          bt = { "terminal" },
        },
      }
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = { indent = { char = "│" }, scope = { enabled = false } },
  },
}
