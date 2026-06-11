require "nvchad.options"

-- add yours here!

vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.cursorline = true

if vim.g.neovide then
  vim.g.neovide_opacity = 0.6
  vim.opt.guifont = "JetBrainsMono Nerd Font Mono:h10"
  vim.g.neovide_floating_blur_amount_x = 3.0
  vim.g.neovide_floating_blur_amount_y = 3.0
  vim.g.neovide_confirm_quit = true
end
