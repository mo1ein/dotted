-- Current Treesitter API; eager loading is required by the upstream plugin.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function() require("configs.treesitter").setup() end,
  },
}
