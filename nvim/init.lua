vim.opt.relativenumber = true

vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "
-- В init.lua, перед загрузкой плагинов

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

local plugins = {
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },
  { import = "plugins" },
}

local theme_file = vim.fn.expand("~/.config/omarchy/current/theme/neovim.lua")
local theme_specs = nil
if vim.uv.fs_stat(theme_file) then
  local ok, result = pcall(dofile, theme_file)
  if ok and type(result) == "table" then
    theme_specs = result
    for _, spec in ipairs(theme_specs) do
      if spec.name == "aether" then
        spec.opts = vim.tbl_deep_extend("force", spec.opts or {}, {
          transparent = true,
          styles = {
            sidebars = "transparent",
            floats = "transparent",
          },
        })
      end
    end
    vim.list_extend(plugins, theme_specs)
  end
end

require("lazy").setup(plugins, lazy_config)

if not vim.uv.fs_stat(vim.g.base46_cache .. "defaults") then
  require("base46").load_all_highlights()
end
pcall(dofile, vim.g.base46_cache .. "defaults")
pcall(dofile, vim.g.base46_cache .. "statusline")

if theme_specs and #theme_specs > 0 and theme_specs[1].name then
  vim.schedule(function()
    pcall(vim.cmd, "colorscheme " .. theme_specs[1].name)
    vim.schedule(function()
      if package.loaded["ibl"] then
        pcall(package.loaded["ibl"].refresh)
      end
    end)
  end)
end

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "aether",
  callback = function()
    vim.schedule(function()
      vim.api.nvim_set_hl(0, "Normal", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "NormalNC", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "SignColumn", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "FoldColumn", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "MsgArea", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "LineNr", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "NONE" })
      vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { bg = "NONE" })
      if package.loaded["ibl"] then
        pcall(package.loaded["ibl"].refresh)
      end
    end)
  end,
})

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
