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
  vim.fn.setenv("PATH", "/usr/bin:/bin:" .. vim.fn.getenv("PATH"))
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

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
