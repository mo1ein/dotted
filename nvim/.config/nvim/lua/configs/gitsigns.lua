-- Original Git gutter symbols and buffer-local actions; colors live in ui.git_colors.
return {
  signs = {
    add = { text = "┃" }, change = { text = "┃" }, delete = { text = "󰍵" },
    topdelete = { text = "‾" }, changedelete = { text = "󱕖" }, untracked = { text = "┆" },
  },
  numhl = true,
  current_line_blame = true,
  current_line_blame_opts = { delay = 400 },
  on_attach = function(bufnr) require("keymaps").apply_buffer(bufnr, "git") end,
}
