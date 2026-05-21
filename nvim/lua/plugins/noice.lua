return {
  "folke/noice.nvim",
  enabled = true,
  lazy = false,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  config = function(_, opts)
    require("notify").setup({ background_colour = "#000000"})
    require("noice").setup(opts)
    vim.opt.cmdheight = vim.g.neovide and 1 or 0
  end,
  opts = {
    cmdline = {
      enabled = true,
      view = "cmdline_popup",
      format = {
        cmdline = { pattern = "^:", icon = "󰘳", lang = "vim" },
      },
    },
    popupmenu = {
      enabled = false,
    },
    lsp = {
      signature = {
        enabled = false,
      },
      hover = {
        enabled = true,
      },
    },
    views = {
      cmdline_popup = {
        position = {
          row = 5,
          col = "50%",
        },
        border = {
          style = "rounded",
          padding = { 0, 1 },
        },
        filter_options = {},
        win_options = {
          winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
        },
      },
    },
  },
}
