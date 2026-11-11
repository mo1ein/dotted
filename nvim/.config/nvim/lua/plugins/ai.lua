-- Compare Avante's chat UI with Sidekick's Codex terminal on separate keys.
return {
  {
    "avante-corp/avante.nvim",
    tag = "v0.5.0",
    version = false,
    -- The release's macOS binaries reference Nix paths; build for this machine.
    build = "make",
    cmd = {
      "Avante", "AvanteAsk", "AvanteChat", "AvanteToggle", "AvanteEdit",
      "AvanteHistory", "AvanteSwitchProvider", "AvanteModels", "AvanteBuild",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      { "ColinKennedy/mega.cmdparse", dependencies = { "ColinKennedy/mega.logging" } },
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
      "hrsh7th/nvim-cmp",
      "ibhagwan/fzf-lua",
      {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "Avante" },
        opts = { file_types = { "markdown", "Avante", "markdown.Avante" } },
      },
    },
    opts = {
      provider = "codex",
      acp_providers = {
        codex = {
          -- Deno runs the maintained adapter without depending on system Node.
          command = "deno",
          args = { "run", "-A", "npm:@agentclientprotocol/codex-acp@2.5.0" },
          env = { CODEX_PATH = vim.fn.exepath "codex" },
        },
      },
      behaviour = { auto_set_keymaps = false, auto_approve_tool_permissions = false },
      selection = { hint_display = "none" },
      selector = { provider = "fzf_lua" },
    },
    keys = {
      { "<leader>aa", "<cmd>AvanteAsk<CR>", mode = { "n", "x" }, desc = "Avante: ask" },
      { "<leader>ac", "<cmd>AvanteChat<CR>", desc = "Avante: chat" },
      { "<leader>at", "<cmd>Avante toggle<CR>", desc = "Avante: toggle" },
      { "<leader>ae", "<cmd>AvanteEdit<CR>", mode = "x", desc = "Avante: edit selection" },
      { "<leader>ah", "<cmd>Avante resume<CR>", desc = "Avante: history" },
      { "<leader>ap", "<cmd>AvanteSwitchProvider<CR>", desc = "Avante: select provider" },
      { "<leader>am", "<cmd>Avante acp models<CR>", desc = "Avante: select agent model" },
    },
  },
  {
    "folke/sidekick.nvim",
    opts = {
      -- CLI-only comparison; Next Edit Suggestions require a Copilot setup.
      nes = { enabled = false },
      cli = { picker = "fzf-lua" },
    },
    keys = {
      {
        "<leader>as",
        function() require("sidekick.cli").toggle { name = "codex", focus = true } end,
        desc = "Sidekick: toggle Codex",
      },
      {
        "<leader>aS",
        function() require("sidekick.cli").select { filter = { installed = true } } end,
        desc = "Sidekick: select CLI",
      },
      {
        "<leader>af",
        function() require("sidekick.cli").send { name = "codex", msg = "{file}" } end,
        desc = "Sidekick: send file to Codex",
      },
      {
        "<leader>av",
        function() require("sidekick.cli").send { name = "codex", msg = "{selection}" } end,
        mode = "x",
        desc = "Sidekick: send selection to Codex",
      },
      {
        "<leader>aP",
        function() require("sidekick.cli").prompt() end,
        mode = { "n", "x" },
        desc = "Sidekick: select prompt",
      },
    },
  },
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      opts.spec[#opts.spec + 1] = { "<leader>a", group = "AI assistants" }
    end,
  },
}
