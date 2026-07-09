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
    local gs = package.loaded.gitsigns

    local function map(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buffer = bufnr, desc = desc })
    end

    map("n", "]c", function()
      if vim.wo.diff then
        return "]c"
      end
      vim.schedule(function()
        gs.next_hunk()
      end)
      return "<Ignore>"
    end, "git: next hunk")

    map("n", "[c", function()
      if vim.wo.diff then
        return "[c"
      end
      vim.schedule(function()
        gs.prev_hunk()
      end)
      return "<Ignore>"
    end, "git: prev hunk")

    map("n", "<leader>gp", gs.preview_hunk, "git: preview hunk")
    map("n", "<leader>gR", gs.reset_hunk, "git: reset hunk")
    map("v", "<leader>gR", function()
      gs.reset_hunk { vim.fn.line ".", vim.fn.line "v" }
    end, "git: reset hunk")
    map("n", "<leader>gs", gs.stage_hunk, "git: stage hunk")
    map("v", "<leader>gs", function()
      gs.stage_hunk { vim.fn.line ".", vim.fn.line "v" }
    end, "git: stage hunk")
    map("n", "<leader>gS", gs.stage_buffer, "git: stage buffer")
    map("n", "<leader>gu", gs.undo_stage_hunk, "git: undo stage hunk")
    map("n", "<leader>gd", gs.diffthis, "git: diff this")
    map("n", "<leader>gD", function()
      gs.diffthis "~"
    end, "git: diff this ~")
    map("n", "<leader>gb", function()
      gs.blame_line { full = true }
    end, "git: blame full")
    map("n", "<leader>gl", function()
      gs.toggle_current_line_blame()
    end, "git: toggle line blame")
    map("n", "<leader>td", gs.toggle_deleted, "git: toggle deleted")

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
