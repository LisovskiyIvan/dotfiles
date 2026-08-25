require "nvchad.options"

-- add yours here!

vim.opt.completeopt = { "menu", "menuone", "noselect", "popup", "nearest" }
vim.opt.cursorline = true

-- Neovim 0.12 new options
vim.opt.autocomplete = false -- true = авто-попап без nvim-cmp, с cmp оставляем false
vim.opt.winborder = "rounded" -- бордер для floating windows (0.12)
vim.opt.pumborder = "rounded" -- бордер для popup menu
vim.opt.pummaxwidth = 40
-- diffopt теперь по дефолту indent-heuristic,inline:char - добавляем word для лучшего inline
vim.opt.diffopt:append("inline:word")
vim.opt.messagesopt:append("wait:500")
vim.opt.jumpoptions:append("view")
-- 0.12: 'smoothscroll' + 'sidescroll' уже, но ускоряем
vim.opt.mousescroll = "ver:1,hor:6"

if vim.g.neovide then
  vim.g.neovide_opacity = 0.75
  vim.opt.guifont = "JetBrainsMono Nerd Font Mono:h12"
  vim.g.neovide_floating_blur_amount_x = 3.0
  vim.g.neovide_floating_blur_amount_y = 3.0
  vim.g.neovide_confirm_quit = true
end
