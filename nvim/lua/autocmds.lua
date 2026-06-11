require "nvchad.autocmds"

vim.filetype.add {
  extension = {
    gd = "gdscript",
    gdshader = "gdshader",
    tscn = "godot_scene",
    tres = "godot_resource",
  },
}

local autosave = { enabled = true }

local blocked_filetypes = {
  "NvimTree", "neo-tree", "lazy", "mason", "help", "qf",
  "terminal", "toggleterm", "alpha", "dashboard", "gitcommit",
  "fugitive", "oil", "diff",
}

local blocked_buftypes = {
  "nofile", "nowrite", "quickfix", "terminal", "prompt",
}

local function contains(list, v)
  for _, x in ipairs(list) do
    if x == v then return true end
  end
  return false
end

local function should_save(bufnr)
  if not autosave.enabled then return false end
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return false end
  if vim.api.nvim_buf_get_name(bufnr) == "" then return false end
  if not vim.bo[bufnr].modified then return false end
  if vim.bo[bufnr].readonly or not vim.bo[bufnr].modifiable then return false end
  if contains(blocked_buftypes, vim.bo[bufnr].buftype) then return false end
  if contains(blocked_filetypes, vim.bo[bufnr].filetype) then return false end
  return true
end

local pending = false
local function save(bufnr)
  if pending then return end
  pending = true
  vim.schedule(function()
    pending = false
    if not should_save(bufnr) then return end
    vim.cmd("silent! keepjumps keepalt update")
  end)
end

local augroup = vim.api.nvim_create_augroup("AutoSave", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "TextChangedI", "FocusLost" }, {
  group = augroup,
  callback = function(args) save(args.buf) end,
})

vim.api.nvim_create_user_command("AutoSaveToggle", function()
  autosave.enabled = not autosave.enabled
  vim.notify("AutoSave: " .. (autosave.enabled and "enabled" or "disabled"))
end, {})

vim.keymap.set("n", "<leader>as", function()
  autosave.enabled = not autosave.enabled
  vim.notify("AutoSave: " .. (autosave.enabled and "enabled" or "disabled"))
end, { desc = "Toggle AutoSave" })
