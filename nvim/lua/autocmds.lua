require "nvchad.autocmds"

local augroup = vim.api.nvim_create_augroup("AutoSave", { clear = true })

vim.api.nvim_create_autocmd("InsertLeave", {
  group = augroup,
  pattern = "*",
  callback = function()
    vim.schedule(function()
      vim.cmd("silent! write")
    end)
  end,
})
