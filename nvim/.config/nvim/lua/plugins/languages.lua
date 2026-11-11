-- Existing language tools kept separate from core editing and UI.
return {
  {
    "fatih/vim-go", ft = "go",
    init = function()
      vim.g.go_def_mapping_enabled = 0
      vim.g.go_gopls_enabled = 0 -- native LSP owns the only gopls client
      vim.g.go_code_completion_enabled = 0 -- nvim-cmp owns completion
      vim.g.go_fmt_autosave = 0 -- conform owns format-on-save
      vim.g.go_doc_popup_window = 0
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim", ft = "markdown",
    cmd = "RenderMarkdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {},
  },
  {
    "iamcco/markdown-preview.nvim", ft = "markdown",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = function() vim.fn["mkdp#util#install"]() end,
  },
  {
    "lervag/vimtex", lazy = false,
    init = function()
      vim.g.vimtex_view_method = require("util.platform").is_mac and "skim" or "zathura"
      vim.g.vimtex_compiler_method = "latexmk"
    end,
  },
  { "cameron-wags/rainbow_csv.nvim", ft = { "csv", "tsv" }, config = true },
}
