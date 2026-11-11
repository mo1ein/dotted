-- Integration: render Git changes in a disposable repo, never modify user files.
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
local function git(args)
  local command = { "git", "-C", directory }
  vim.list_extend(command, args)
  local result = vim.system(command, { text = true }):wait()
  assert(result.code == 0, result.stderr)
end
git { "init", "-q" }
local path = directory .. "/changes.txt"
local original, modified = {}, {}
for i = 1, 30 do
  original[#original + 1] = "line " .. i
  if i ~= 15 then modified[#modified + 1] = i == 5 and "changed line" or original[i] end
  if i == 20 then modified[#modified + 1] = "added line" end
end
vim.fn.writefile(original, path)
git { "add", "changes.txt" }
git { "-c", "user.name=Neovim Test", "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false", "commit", "--no-verify", "-qm", "fixture" }
vim.fn.writefile(modified, path)
vim.cmd.edit(vim.fn.fnameescape(path))
local buf = vim.api.nvim_get_current_buf()
assert(vim.wait(5000, function()
  local status = vim.b[buf].gitsigns_status_dict
  return status and status.added == 1 and status.changed == 1 and status.removed == 1
end, 20), "Gitsigns didn't detect the fixture changes")
local namespace = vim.api.nvim_get_namespaces().gitsigns_signs_
assert(namespace)
local function rendered()
  local found = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
    local details = mark[4]
    if details.sign_hl_group then found[details.sign_hl_group] = details end
  end
  return found
end
assert(vim.wait(5000, function()
  vim.cmd.redraw()
  local signs = rendered()
  return signs.GitSignsAdd and signs.GitSignsChange and signs.GitSignsDelete
end, 20), "Git gutter signs didn't render")
local signs = rendered()
for kind, icon in pairs { Add = "┃", Change = "┃", Delete = "󰍵" } do
  local sign = signs["GitSigns" .. kind]
  assert(vim.trim(sign.sign_text) == icon, "Wrong rendered Git symbol: " .. kind)
  assert(sign.number_hl_group == "GitSigns" .. kind .. "Nr", "Colored line numbers lost")
end
for _, scheme in ipairs { "dotted-onedark", "vscode-dark-2026", "habamax" } do
  vim.cmd.colorscheme(scheme)
  vim.wait(100)
  local function fg(group) return vim.api.nvim_get_hl(0, { name = group, link = false }).fg end
  assert(fg("GitSignsChange") == (fg("DiffChange") or fg("Changed") or 0x70aeff))
end
assert(vim.v.errmsg == "", vim.v.errmsg)
print "Gitsigns: real added/changed/deleted gutter symbols, colored line numbers, and theme switching passed"
vim.cmd "qa!"
