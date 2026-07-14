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
        -- "v_analyzer", -- patched manually, do not let Mason overwrite
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
    "HakonHarnes/img-clip.nvim",
    ft = { "markdown", "norg", "org" },
    keys = {
      { "<leader>p", "<cmd>PasteImage<cr>", mode = { "n" }, desc = "Paste clipboard image" },
    },
    opts = {
      default = { dir_path = "assets" },
    },
  },

  {
    "3rd/image.nvim",
    event = "VeryLazy",
    cond = not vim.g.neovide,
    opts = {
      rocks = { hererocks = true },
      only_render_image_at_cursor = true,
    },
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.icons" },
    opts = {
      link = {
        image = '', -- не заменять ![](path) иконкой
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
          local root = vim.fs.root(0, { "selene.toml", ".luaurc", ".git" })
          if root then
            lint.try_lint(nil, { cwd = root })
          else
            lint.try_lint()
          end
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
    "nvim-tree/nvim-tree.lua",
    opts = function()
      local config = require "nvchad.configs.nvimtree"
      config.renderer.highlight_git = "all"
      config.on_attach = function(bufnr)
        require("nvim-tree.keymap").on_attach_default(bufnr)
        local api = require "nvim-tree.api"
        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, nowait = true }
        end

        vim.keymap.set("n", ">", function()
          api.tree.resize { relative = 5 }
        end, opts "increase width")
        vim.keymap.set("n", "<", function()
          api.tree.resize { relative = -5 }
        end, opts "decrease width")
        vim.keymap.set("n", "0", function()
          api.tree.resize { absolute = 30 }
        end, opts "reset width")
      end
      return config
    end,
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
        "v",
      },
      indent = { enable = true },
    },
  },
}
