-- Focused tools, loaded only on use; the existing UI remains owned Lua.
return {
  {
    "folke/trouble.nvim", cmd = "Trouble", lazy = true,
    opts = { auto_preview = false, focus = true, open_no_results = true },
  },
  { "stevearc/overseer.nvim", cmd = { "OverseerRun", "OverseerToggle" }, lazy = true, opts = {} },
  {
    "NeogitOrg/neogit", cmd = { "Neogit", "NeogitLog", "NeogitCommit" }, lazy = true,
    dependencies = { "ibhagwan/fzf-lua" },
    opts = {
      graph_style = "unicode", filewatcher = { enabled = false },
      integrations = { fzf_lua = true, diffview = false },
    },
  },
}
