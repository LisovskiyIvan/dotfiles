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

-- Escape
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("i", "jj", "<ESC>")

-- Buffer (NvChad already has <leader>x for close)
map("n", "<leader>bo", function()
  local cur = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if buf ~= cur and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end, { desc = "Close other buffers" })
map("n", "H", "<cmd>bp<cr>", { desc = "Previous buffer" })
map("n", "L", "<cmd>bn<cr>", { desc = "Next buffer" })

-- LSP
map("n", "gd", function()
  vim.lsp.buf.definition { on_list = jump_to_first_definition }
end, { desc = "LSP go to definition" })
map("n", "gr", vim.lsp.buf.references, { desc = "LSP references" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>.", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>ti", function()
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

-- Diagnostics
map("n", "<leader>xx", vim.diagnostic.open_float, { desc = "Diagnostic float" })

-- Git
map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<leader>ghd", function()
  require("gitsigns").toggle_signs()
end, { desc = "Toggle diff hunks" })
map("n", "]h", function()
  if vim.wo.diff then vim.cmd("normal! ]c") else require("gitsigns").next_hunk() end
end, { desc = "Next hunk" })
map("n", "[h", function()
  if vim.wo.diff then vim.cmd("normal! [c") else require("gitsigns").prev_hunk() end
end, { desc = "Prev hunk" })

-- UI
map("n", "<leader>uw", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle soft wrap" })

-- Search
map("n", "<leader>s", function()
  vim.fn.feedkeys("/" .. vim.fn.expand("<cword>"), "n")
end, { desc = "Search word under cursor" })

-- Override NvChad telescope keymaps with fff/native
map("n", "<leader>ff", "<cmd>FFFFind<cr>", { desc = "Find files" })
map("n", "<leader>fa", "<cmd>FFFFind<cr>", { desc = "Find all files" })
map("n", "<leader>fw", "<cmd>FFFFind<cr>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>buffers<cr>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>help<cr>", { desc = "Find help" })
map("n", "<leader>ma", "<cmd>marks<cr>", { desc = "Find marks" })
map("n", "<leader>fo", "<cmd>browse oldfiles<cr>", { desc = "Recent files" })
map("n", "<leader>cm", "<cmd>LazyGit<cr>", { desc = "Git commits" })
map("n", "<leader>gt", "<cmd>LazyGit<cr>", { desc = "Git status" })
map("n", "<leader>fz", "<nop>", { desc = "Buffer fuzzy (disabled)" })
map("n", "<leader>pt", "<nop>", { desc = "Pick term (use <A-v>/<A-h>/<A-i>)" })

-- Quickfix
map("n", "<leader>q", function()
  vim.cmd("cclose")
  vim.cmd("lclose")
end, { desc = "Close quickfix & loclist" })
