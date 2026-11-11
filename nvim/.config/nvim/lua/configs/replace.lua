-- Project replacement reuses grug-far with the file finder's float and theme roles.
return {
  windowCreationCommand = "lua require('ui.replace').project_window()",
  transient = true,
  startInInsertMode = true,
  showCompactInputs = true,
  showEngineInfo = false,
  wrap = false,
  helpWindow = { border = "rounded" },
  historyWindow = { border = "rounded" },
  previewWindow = { border = "rounded" },
  hooks = {
    on_before_edit_file = function(finish, file)
      local path = vim.uv.fs_realpath(file.path) or vim.fs.normalize(vim.fn.fnamemodify(file.path, ":p"))
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        name = vim.uv.fs_realpath(name) or name
        if name == path and vim.bo[buf].modified then
          finish("error", "Save modified buffer before replacing: " .. path)
          return
        end
      end
      finish("success")
    end,
  },
  keymaps = {
    replace = { n = "<C-s>", i = "<C-s>" },
    syncLine = { n = "<C-g>" },
    close = { n = "q" },
  },
}
