return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      local cmp = require "cmp"

      opts.mapping = opts.mapping or cmp.mapping.preset.insert()
      opts.mapping["<Space>"] = nil

      return opts
    end,
  },

  { "nvim-telescope/telescope.nvim", enabled = false },

  {
    "kdheepak/lazygit.nvim",
    lazy = false,
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "williamboman/mason-lspconfig.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lspconfig" },
    opts = {
      ensure_installed = {
        "ts_ls",
        "rust_analyzer",
        "gopls",
        "pyright",
      },
    },
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc",
        "html", "css", "go", "rust",
        "javascript", "typescript", "tsx", "jsx",
        "python",
        "gdscript", "godot_resource", "godot_scene",
      },
    },
  },
}
