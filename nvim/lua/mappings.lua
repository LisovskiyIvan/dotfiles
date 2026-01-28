require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

local function jump_to_first_definition(opts)
  local item = opts.items[1]
  if not item then
    return
  end

  if item.bufnr and item.bufnr > 0 then
    vim.api.nvim_set_current_buf(item.bufnr)
  elseif item.filename then
    vim.cmd(("edit %s"):format(vim.fn.fnameescape(item.filename)))
  end

  vim.api.nvim_win_set_cursor(0, { item.lnum, math.max(item.col - 1, 0) })
end

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("i", "jj", "<ESC>")
map("n", "gd", function()
  vim.lsp.buf.definition { on_list = jump_to_first_definition }
end, { desc = "LSP go to definition" })
map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<leader>q", function()
  vim.cmd("cclose")
  vim.cmd("lclose")
end, { desc = "Close quickfix & loclist" })
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
