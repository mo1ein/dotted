-- Neovim's Vim and Lua Markdown plugins both undo the same normal-mode maps.
-- Keep the Lua cleanup and the Vim visual-map cleanup when FileType is replayed.
local undo = vim.b.undo_ftplugin
if type(undo) == "string" and undo:find("v:lua.vim.treesitter.stop()", 1, true) then
  vim.b.undo_ftplugin = undo:gsub("|sil! nunmap <buffer> %[%[", ""):gsub("|sil! nunmap <buffer> %]%]", "")
end
