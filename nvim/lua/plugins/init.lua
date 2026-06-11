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
    config = function()
      require("configs.cmp")
    end,
  },

  { "L3MON4D3/LuaSnip" },
  {
    "rafamadriz/friendly-snippets",
    event = "VeryLazy",
  },

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
        "clangd",
        "luau_lsp",
        "oxlint",
      },
    },
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    event = "VeryLazy",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "stylua",
        "selene",
      },
    },
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require "lint"
      lint.linters_by_ft = {
        lua = { "selene" },
        luau = { "selene" },
      }
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    -- No need to install gitsigns separately — NvChad already provides it.
    -- This spec only overrides NvChad's default gitsigns options.
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true, -- show inline blame on current line
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol", -- End Of Line (right-aligned virtual text)
        delay = 0, -- ms before showing
        ignore_whitespace = false,
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc",
        "html", "css", "c", "go", "rust",
        "javascript", "typescript", "tsx", "jsx",
        "python",
        "gdscript", "godot_resource", "godot_scene",
        "gleam",
        "luau",
      },
    },
  },
}
