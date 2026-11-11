-- Cached catalog lookup and native completion index; no theme code runs here.
local M = {}
local entries, by_scheme

function M.entries()
  if entries then return entries end
  entries, by_scheme = vim.deepcopy(require "config.themes"), {}
  for _, entry in ipairs(require("themes.bundled_catalog").entries()) do entries[#entries + 1] = entry end
  local startup = require "config.theme"
  -- Preserve the existing one-file startup theme format, including custom repos.
  local configured
  for _, entry in ipairs(entries) do
    if vim.tbl_contains(entry.schemes, startup.colorscheme) then configured = entry; break end
  end
  if not configured then
    configured = { schemes = { startup.colorscheme } }
    entries[#entries + 1] = configured
  end
  for _, key in ipairs { "plugin", "module", "name", "opts" } do
    if startup[key] ~= nil then configured[key] = vim.deepcopy(startup[key]) end
  end
  local owners = {}
  for _, entry in ipairs(entries) do
    if entry.plugin then
      entry.name = entry.name or entry.plugin:match "([^/]+)$"
      assert(not owners[entry.name], "Duplicate theme provider: " .. entry.name)
      owners[entry.name] = true
    end
    for _, scheme in ipairs(entry.schemes) do
      assert(scheme:match "^[%w_-]+$", "Invalid colorscheme name: " .. scheme)
      assert(not by_scheme[scheme], "Duplicate colorscheme: " .. scheme)
      by_scheme[scheme] = entry
    end
  end
  return entries
end

function M.find(scheme)
  M.entries()
  return by_scheme[scheme]
end

function M.index()
  -- Tiny forwarding files make unloaded themes visible to native :colorscheme
  -- completion. These contain no highlights and are rewritten only on changes.
  local root = vim.fn.stdpath "cache" .. "/theme-index"
  local wanted = {}
  for _, entry in ipairs(M.entries()) do
    if entry.plugin or entry.bundled then
      for _, scheme in ipairs(entry.schemes) do wanted[#wanted + 1] = scheme end
    end
  end
  table.sort(wanted)
  local manifest = root .. "/schemes"
  local old = vim.fn.filereadable(manifest) == 1 and vim.fn.readfile(manifest) or {}
  if not vim.deep_equal(old, wanted) then
    vim.fn.mkdir(root .. "/colors", "p")
    local keep = {}
    for _, scheme in ipairs(wanted) do
      keep[scheme] = true
      vim.fn.writefile({
        "-- Generated theme forwarding entry; no highlight cache.",
        ('require("config.theme_loader").source(%q)'):format(scheme),
      }, root .. "/colors/" .. scheme .. ".lua")
    end
    for _, scheme in ipairs(old) do
      if scheme:match "^[%w_-]+$" and not keep[scheme] then
        vim.fn.delete(root .. "/colors/" .. scheme .. ".lua")
      end
    end
    vim.fn.writefile(wanted, manifest)
  end
  if not vim.tbl_contains(vim.opt.rtp:get(), root) then vim.opt.rtp:prepend(root) end
end

return M
