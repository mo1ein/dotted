-- Navigation, git, and formatting; each plugin has an explicit load trigger.
return {
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function() return require("ui.panel").finder() end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPost", "BufNewFile" },
    opts = function() return require "configs.gitsigns" end,
    config = function(_, opts)
      require("gitsigns").setup(opts)
      require("ui.git_colors").setup()
    end,
  },
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    opts = function() return require "configs.conform" end,
  },
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = function() return require "configs.replace" end,
  },
}
