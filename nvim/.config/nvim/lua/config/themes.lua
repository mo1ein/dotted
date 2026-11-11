-- Theme catalog only. Add a provider here to install it and expose its schemes.
-- Inactive providers are not loaded. Each uses its own public setup options.
return {
  {
    module = "themes.onedark", schemes = { "dotted-onedark" },
    opts = function() return { transparent = require("config.transparency").enabled } end,
  },
  {
    plugin = "nickkadutskyi/jb.nvim", module = "jb", schemes = { "jb" },
    opts = {},
  },
  {
    plugin = "folke/tokyonight.nvim", module = "tokyonight",
    schemes = { "tokyonight", "tokyonight-night", "tokyonight-storm", "tokyonight-moon", "tokyonight-day" },
    light = { "tokyonight-day" }, opts = {},
  },
  {
    plugin = "catppuccin/nvim", name = "catppuccin", module = "catppuccin",
    schemes = { "catppuccin", "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha" },
    light = { "catppuccin-latte" }, opts = {},
  },
  {
    plugin = "rebelot/kanagawa.nvim", module = "kanagawa",
    schemes = { "kanagawa", "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus" },
    light = { "kanagawa-lotus" }, opts = {},
  },
  {
    plugin = "rose-pine/neovim", name = "rose-pine", module = "rose-pine",
    schemes = { "rose-pine", "rose-pine-main", "rose-pine-moon", "rose-pine-dawn" },
    light = { "rose-pine-dawn" }, opts = {},
  },
  {
    plugin = "ellisonleao/gruvbox.nvim", module = "gruvbox", schemes = { "gruvbox" },
    opts = {},
  },
  {
    plugin = "EdenEast/nightfox.nvim", module = "nightfox",
    schemes = { "nightfox", "dayfox", "dawnfox", "duskfox", "nordfox", "terafox", "carbonfox" },
    light = { "dayfox", "dawnfox" }, opts = {},
  },
  { plugin = "navarasu/onedark.nvim", module = "onedark", schemes = { "onedark" }, opts = { style = "darker" } },
  { plugin = "neanias/everforest-nvim", module = "everforest", schemes = { "everforest" }, opts = {} },
  { plugin = "AlexvZyl/nordic.nvim", module = "nordic", schemes = { "nordic" }, opts = {} },
  {
    plugin = "projekt0n/github-nvim-theme", module = "github-theme",
    schemes = { "github_dark", "github_dark_default", "github_dark_dimmed", "github_dark_high_contrast", "github_dark_colorblind", "github_dark_tritanopia", "github_light", "github_light_default", "github_light_high_contrast", "github_light_colorblind", "github_light_tritanopia" },
    light = { "github_light", "github_light_default", "github_light_high_contrast", "github_light_colorblind", "github_light_tritanopia" },
    opts = {},
  },
  { plugin = "Mofiqul/dracula.nvim", module = "dracula", schemes = { "dracula", "dracula-soft" }, opts = {} },
  { plugin = "nyoom-engineering/oxocarbon.nvim", schemes = { "oxocarbon" } },
  { plugin = "Mofiqul/vscode.nvim", module = "vscode", schemes = { "vscode" }, opts = {} },
}
