vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

local autocmd = vim.api.nvim_create_autocmd

local ui_caches = { "blankline", "cmp", "devicons", "git", "lsp", "mason", "nvcheatsheet", "nvimtree", "statusline", "tbline", "telescope", "term", "whichkey" }

local function apply()
  local ok, utils = pcall(require, "jb.utils")
  if not ok then
    return
  end
  local jb_init = require "jb"
  local config = require "jb.config"
  local opts = config.extend()
  local profile = vim.o.background
  local palette = utils.read_palette "/lua/jb/palette.json"
  local colors = palette.colors
  local highlights = palette.highlights

  vim.g.colors_name = "onedark"

  if vim.g.base46_cache then
    pcall(dofile, vim.g.base46_cache .. "defaults")
  end

  for _, name in ipairs(ui_caches) do
    if vim.g.base46_cache then
      local f = vim.g.base46_cache .. name
      if vim.fn.filereadable(f) == 1 then
        pcall(dofile, f)
      end
    end
  end

  local hl_groups = {}
  local set_hl_delayed = {}

  for section, groups in pairs(highlights) do
    if section == "Builtin.Languages" or section == "Builtin.Diagnostic" or section:match("^Treesitter%.") or section:match("^Syntax%.") or section:match("^Semantic%.") then
      for group, attrs in pairs(groups) do
        local hl = {}

        if type(attrs) == "string" and string.find(attrs, "|") ~= nil then
          local props = utils.get_hl_props(colors, attrs, profile)
          if group == props.name then
            hl = props.hl
          else
            if hl_groups[props.name] == nil then
              vim.api.nvim_set_hl(0, props.name, jb_init.disable_hl_args(props.hl, opts))
              hl_groups[props.name] = true
            end
            hl.link = props.name
          end
        elseif type(attrs) == "string" and attrs ~= "" then
          hl.link = attrs
          set_hl_delayed[group] = hl
        elseif type(attrs) == "table" then
          local last_hl_name = nil
          for attr, value in pairs(attrs) do
            if attr ~= "nolink" then
              if type(value) == "string" and string.find(value, "|") ~= nil then
                last_hl_name = string.gsub(value, "|", "_")
                local props = utils.get_hl_props(colors, value, profile)
                hl[attr] = props.prop or props.hl[attr]
              else
                hl[attr] = value
              end
            end
          end

          local group_name = (utils.table_length(attrs) == 1 and last_hl_name ~= nil)
            and last_hl_name .. "-" .. last_hl_name
            or group .. "_Custom"

          local nolink = attrs.nolink
          if not nolink then
            vim.api.nvim_set_hl(0, group_name, jb_init.disable_hl_args(hl, opts))
            hl.link = group_name
          else
            vim.api.nvim_set_hl(0, group, jb_init.disable_hl_args(hl, opts))
          end
        end

        if attrs ~= nil and attrs ~= "" then
          local props = hl.link ~= nil and { link = hl.link } or hl
          vim.api.nvim_set_hl(0, group, jb_init.disable_hl_args(props, opts))
        end
      end
    end
  end

  for group, hl in pairs(set_hl_delayed) do
    local props = hl.link ~= nil and { link = hl.link } or hl
    vim.api.nvim_set_hl(0, group, jb_init.disable_hl_args(props, opts))
  end

  vim.g.colors_name = "jb"
end

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

require("lazy").setup({
  { import = "plugins" },
}, lazy_config)

require "options"
vim.schedule(function()
  require "mappings"
end)

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      apply()
    end)
  end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    if vim.g.colors_name ~= "jb" then
      apply()
    end
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "FilePost",
  once = true,
  callback = function()
    vim.schedule(apply)
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    apply()
  end,
})
