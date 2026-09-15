return {
  signs = {
    add = { text = "│" },
    change = { text = "│" },
    delete = { text = "󰍵" },
    topdelete = { text = "‾" },
    changedelete = { text = "󱕖" },
    untracked = { text = "┆" },
  },

  numhl = true,

  current_line_blame = true,
  current_line_blame_opts = {
    delay = 400,
    ignore_whitespace = false,
  },
  current_line_blame_formatter = "<author>, <author_time:%R>",

  on_attach = function(bufnr)
    require("keymaps").apply_buffer(bufnr, "git")

    local function set_git_highlights()
      local hl = function(group, opts)
        vim.api.nvim_set_hl(0, group, opts)
      end

      local function get_hl_fg(name)
        local h = vim.api.nvim_get_hl(0, { name = name })
        return h.fg
      end

      local add_fg = get_hl_fg("DiffAdd") or get_hl_fg("Added") or 0x73BD79
      local change_fg = get_hl_fg("DiffChange") or get_hl_fg("Changed") or 0x70AEFF
      local delete_fg = get_hl_fg("DiffDelete") or get_hl_fg("Removed") or 0x6F737A
      local sign_fg = get_hl_fg("Comment") or 0x636D83

      hl("GitSignsAdd", { fg = add_fg })
      hl("GitSignsChange", { fg = change_fg })
      hl("GitSignsDelete", { fg = delete_fg })
      hl("GitSignsChangedelete", { fg = change_fg })
      hl("GitSignsTopdelete", { fg = delete_fg })
      hl("GitSignsUntracked", { fg = sign_fg })

      hl("GitSignsAddNr", { fg = add_fg })
      hl("GitSignsChangeNr", { fg = change_fg })
      hl("GitSignsDeleteNr", { fg = delete_fg })

      local add_bg = get_hl_fg("DiffAdd")
      local change_bg = get_hl_fg("DiffChange")
      if add_bg then
        hl("GitSignsAddLn", { fg = "none", bg = add_bg, nocombine = true })
      end
      if change_bg then
        hl("GitSignsChangeLn", { fg = "none", bg = change_bg, nocombine = true })
      end

      hl("GitSignsCurrentLineBlame", { fg = sign_fg, italic = true })
    end

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("GitSignsHighlights", { clear = true }),
      callback = function()
        vim.schedule(set_git_highlights)
      end,
    })

    if vim.g.colors_name then
      vim.schedule(set_git_highlights)
    end
  end,
}
