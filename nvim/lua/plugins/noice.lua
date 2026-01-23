return {
  "folke/noice.nvim",
  lazy = false,
  dependencies = {
    "MunifTanjim/nui.nvim",
    "rcarriga/nvim-notify",
  },
  config = function(_, opts)
    vim.notify("Noice config called", vim.log.levels.INFO)
    require("noice").setup(opts)
    vim.opt.cmdheight = 0
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
      enabled = true,
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
