-- VS Code keys layered over the default preset; terminal support varies.
return {
  name = "vscode",
  description = "VS Code keys layered over the default leader keys.",
  extends = "default",
  bindings = {
    ["find.files"] = { linux = { "<leader>ff", "<C-p>" }, macos = { "<leader>ff", "<C-p>", "<D-p>" } },
    ["find.commands"] = { linux = { "<leader>p", "<C-S-p>" }, macos = { "<leader>p", "<C-S-p>", "<D-S-p>" } },
    ["find.grep"] = { linux = { "<leader>fg", "<C-S-f>" }, macos = { "<leader>fg", "<C-S-f>", "<D-S-f>" } },
    ["find.buffer"] = { "<leader>fz", "<C-f>", "F" },
    ["find.replace"] = { linux = { "<leader>sr", "<C-S-h>", "<C-S-r>" }, macos = { "<leader>sr", "<C-S-h>", "<D-S-h>", "<C-S-r>" } },
    ["find.replace_buffer"] = { linux = { "<leader>sb", "<leader>sR", "<C-r>" }, macos = { "<leader>sb", "<C-r>", "<D-A-f>", "<leader>sR" } },
    ["lsp.definition"] = { "gd", "<F12>" },
    ["lsp.references"] = { "grr", "<S-F12>" },
    ["lsp.rename"] = { "<leader>cr", "grn", "<F2>" },
    ["lsp.code_action"] = { "<leader>ca", "<C-.>" },
    ["editor.format"] = { linux = { "<leader>fm", "<S-A-f>" }, macos = { "<leader>fm", "<S-A-f>", "<D-S-i>" } },
    ["editor.comment"] = { linux = { "<leader>/", "<C-/>", "<C-_>" }, macos = { "<leader>/", "<C-/>", "<C-_>", "<D-/>" } },
    ["editor.run_file"] = { "<leader>r", "<C-F5>" },
    ["ui.file_explorer"] = { linux = { "<leader>e", "<C-e>", "<C-b>" }, macos = { "<leader>e", "<C-e>", "<C-b>", "<D-b>" } },
    -- Platform MRU keys are inherited from default; Tab stays sequential.
    ["debug.continue"] = { "<leader>dc", "<F5>" },
    ["debug.breakpoint"] = { "<leader>db", "<F9>" },
    ["debug.step_over"] = { "<leader>do", "<F10>" },
    ["debug.step_into"] = { "<leader>di", "<F11>" },
    ["debug.step_out"] = { "<leader>dO", "<S-F11>" },
  },
}
