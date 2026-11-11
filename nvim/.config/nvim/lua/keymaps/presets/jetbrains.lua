-- JetBrains keys layered over the default preset; no IDE/distribution dependency.
return {
  name = "jetbrains",
  description = "JetBrains / IdeaVim keys layered over the default leader keys.",
  extends = "default",
  bindings = {
    ["find.files"] = { linux = { "<leader>ff", "<C-S-n>" }, macos = { "<leader>ff", "<C-S-n>", "<D-S-o>" } },
    ["find.grep"] = { linux = { "<leader>fg", "<C-S-f>" }, macos = { "<leader>fg", "<C-S-f>", "<D-S-f>" } },
    ["find.commands"] = { linux = { "<leader>p", "<C-S-a>" }, macos = { "<leader>p", "<C-S-a>", "<D-S-a>" } },
    ["find.buffer"] = { "<leader>fz", "<C-f>", "F" },
    ["find.replace"] = { linux = { "<leader>sr", "<C-S-r>" }, macos = { "<leader>sr", "<C-S-r>", "<D-S-r>" } },
    ["find.replace_buffer"] = { linux = { "<leader>sb", "<leader>sR", "<C-r>" }, macos = { "<leader>sb", "<C-r>", "<D-r>", "<leader>sR" } },
    ["lsp.definition"] = { linux = { "gd", "<C-b>" }, macos = { "gd", "<C-b>", "<D-b>" } },
    ["lsp.references"] = { "grr", "<A-F7>" },
    ["lsp.implementations"] = { "gri", "<C-A-b>" },
    ["lsp.rename"] = { "<leader>cr", "grn", "<S-F6>" },
    ["lsp.code_action"] = { "<leader>ca", "<A-CR>" },
    ["editor.format"] = { linux = { "<leader>fm", "<C-A-l>" }, macos = { "<leader>fm", "<C-A-l>", "<D-A-l>" } },
    ["editor.comment"] = { linux = { "<leader>/", "<C-/>", "<C-_>" }, macos = { "<leader>/", "<C-/>", "<C-_>", "<D-/>" } },
    ["editor.run_file"] = { "<leader>r", "<S-F10>" },
    ["ui.file_explorer"] = { "<leader>e", "<C-e>", "<A-1>" },
    ["terminal.toggle_horizontal"] = { "<A-h>", "<A-F12>" },
    ["buffer.close"] = { "<leader>x", "<C-F4>" },
    ["window.zoom"] = { "<leader>z", "<C-S-F12>" },
    -- Debug F-keys and leader aliases are shared with default. Native macOS
    -- start/resume chords stay here so default keeps Vim's Ctrl-d scrolling.
    ["debug.continue"] = {
      linux = { "<leader>dc", "<S-F9>", "<F9>" },
      windows = { "<leader>dc", "<S-F9>", "<F9>" },
      macos = { "<leader>dc", "<S-F9>", "<F9>", "<C-d>", "<D-A-r>" },
    },
  },
}
