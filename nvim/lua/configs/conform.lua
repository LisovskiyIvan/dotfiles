local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    python = { "black" },
    javascript = { "oxfmt" },
    javascriptreact = { "oxfmt" },
    typescript = { "oxfmt" },
    typescriptreact = { "oxfmt" },
    zig = { "zigfmt" },
    c = { "clang_format" },
    cpp = { "clang_format" },
    -- css = { "prettier" },
    -- html = { "prettier" },
  },

  formatters = {
    stylua = {
      command = vim.fn.stdpath "data" .. "/mason/bin/stylua",
    },
  },

  -- format_on_save = {
  --   -- These options will be passed to conform.format()
  --   timeout_ms = 500,
  --   lsp_fallback = true,
  -- },
}

return options
