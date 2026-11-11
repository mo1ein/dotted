vim.opt_local.expandtab = false
vim.b.undo_ftplugin = (vim.b.undo_ftplugin or "") .. "|setlocal expandtab<"
