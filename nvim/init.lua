local is_windows = vim.fn.has("win32") == 1

if is_windows then
  vim.opt.shell = "C:/cygwin64/bin/zsh.exe"
  vim.opt.shellcmdflag = "-c"
end

vim.opt.relativenumber = true

vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "
-- В init.lua, перед загрузкой плагинов
local function setup_cygwin_paths()
  -- Патчим vim.system или аналогичные функции
  local original_spawn = vim.system or vim.loop.spawn

  -- ИЛИ устанавливаем переменные окружения для libuv
  vim.fn.setenv("SHELL", "C:/cygwin64/bin/zsh.exe")
  local base_path = vim.fn.getenv("PATH")
  local myvimrc = vim.fn.expand("$MYVIMRC")
  if myvimrc ~= nil and myvimrc ~= "" then
    local config_dir = vim.fn.fnamemodify(myvimrc, ":h")
    local dotfiles_root = vim.fn.fnamemodify(config_dir, ":h")
    local dotfiles_bin = dotfiles_root .. "\\bin"
    if vim.fn.isdirectory(dotfiles_bin) == 1 then
      base_path = dotfiles_bin .. ";" .. base_path
    end
  end
  local userprofile = vim.fn.getenv("USERPROFILE")
  if userprofile ~= nil and userprofile ~= "" then
    local winget_links = userprofile .. "\\AppData\\Local\\Microsoft\\WinGet\\Links"
    base_path = base_path .. ";" .. winget_links
    local winget_packages = userprofile .. "\\AppData\\Local\\Microsoft\\WinGet\\Packages"
    local lazygit_candidates = vim.fn.glob(winget_packages .. "/**/lazygit.exe", true, true)
    if type(lazygit_candidates) == "table" and #lazygit_candidates > 0 then
      local lazygit_dir = vim.fn.fnamemodify(lazygit_candidates[1], ":h")
      base_path = base_path .. ";" .. lazygit_dir
    end
  end
  vim.fn.setenv("PATH", base_path)
end

if is_windows then
  setup_cygwin_paths()
end
-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme (compile if cache missing)
if not vim.uv.fs_stat(vim.g.base46_cache .. "defaults") then
  require("base46").load_all_highlights()
end
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
