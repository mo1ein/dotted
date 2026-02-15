local lazy_status = require('lazy.status')

-- Truncate helper
local function trunc(trunc_width, trunc_len, hide_width, no_ellipsis)
  return function(str)
    local win_width = vim.o.columns
    if hide_width and win_width < hide_width then
      return ''
    elseif trunc_width and trunc_len and win_width < trunc_width and #str > trunc_len then
      return str:sub(1, trunc_len) .. (no_ellipsis and '' or '…')
    end
    return str
  end
end

-- LSP status
local function lsp_status_all()
  local haveServers = false
  local names = {}
  for _, server in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
    haveServers = true
    table.insert(names, server.name)
  end
  if not haveServers then return '' end
  if vim.g.custom_lualine_show_lsp_names then
    return ' ' .. table.concat(names, ',')
  end
  return ' '
end

-- Helpers to skip default values
local encoding_only_if_not_utf8 = function()
  local ret, _ = (vim.bo.fenc or vim.go.enc):gsub('^utf%-8$', '')
  return ret
end

local fileformat_only_if_not_unix = function()
  local ret, _ = vim.bo.fileformat:gsub('^unix$', '')
  return ret
end

-- Load theme correctly if using tokyonight
local theme = function()
  if vim.g.colors_name and vim.g.colors_name:match('^tokyonight') then
    return require('lualine.themes.' .. vim.g.colors_name)
  end
  return 'auto'
end

-- Load plugin with setup
require('lualine').setup({
  options = {
    theme = theme(),
    component_separators = { left = '╲', right = '╱' },
    section_separators = { left = '', right = '' },
    disabled_filetypes = { 'alpha', 'neo-tree', 'snacks_dashboard' },
    ignore_focus = { 'trouble' },
    globalstatus = true,
  },
  sections = {
    lualine_a = {
      {
        'mode',
        fmt = trunc(130, 3, 0, true),
      },
    },
    lualine_b = {
      {
        'branch',
        fmt = trunc(70, 15, 65, true),
        separator = '',
      },
    },
    lualine_c = {
      {
        'pretty_path',
        providers = {
          default = require('util/pretty_path_harpoon'),
        },
        directories = {
          max_depth = 4,
        },
        highlights = {
          newfile = 'LazyProgressDone',
        },
        separator = '',
      },
    },
    lualine_x = {
      {
        function()
          return require('auto-session.lib').current_session_name(true)
        end,
        cond = function()
          return vim.g.custom_lualine_show_session_name
        end,
      },
      {
        'diagnostics',
        symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' },
        separator = '',
      },
      {
        'diff',
        symbols = {
          added = ' ',
          modified = ' ',
          removed = ' ',
        },
        fmt = trunc(0, 0, 60, true),
        separator = '',
      },
      {
        lsp_status_all,
        separator = '',
      },
      {
        encoding_only_if_not_utf8,
        separator = '',
      },
      {
        fileformat_only_if_not_unix,
        separator = '',
      },
      {
        lazy_status.updates,
        cond = lazy_status.has_updates,
        color = 'LazyProgress',
      },
      {
        function()
          return vim.b.trouble_lualine and ' ' or ''
        end,
        separator = '',
      },
    },
    lualine_y = { 'filetype' },
    lualine_z = {
      {
        'location',
        separator = '',
      },
      {
        'progress',
        separator = '',
      },
    },
  },
  extensions = { 'quickfix', 'lazy', 'neo-tree', 'toggleterm', 'trouble' },
})

