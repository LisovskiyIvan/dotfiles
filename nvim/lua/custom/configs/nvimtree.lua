local M = {}

M.ui = {
  -- If you are using a NvChad fork, you can override their defaults here
  theme = "onedark",
  theme_toggle = { "onedark", "one_light" },
  transparency = false,
}

M.plugins = {}

-- Disable nvim-tree auto-following files
M.plugins.nvimtree = {
  update_focused_file = {
    enable = false,
    update_root = false,
  },
}

M.mappings = {}

return M