return {
  "ray-x/go.nvim",
  dependencies = {
    "ray-x/guihua.lua",
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  ft = "go",
  build = ':lua require("go.install").update_all_sync()',
  opts = {
    -- gopls отключён намеренно; go.nvim остаётся для run/test/lint.
    lsp_cfg = false,
    diagnostic = true,
    dap_debug = false,
    test_runner = "go",
    run_in_floaterm = true,
    lint = "golangci-lint",
    lint_prompt_style = "vt",
    lint_on_save = false,
  },
}
