return {
  "dmtrkovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  cmd = { "FFFFind", "FFFScan" },
  keys = {
    { "<leader>f", "<cmd>FFFFind<cr>", desc = "Find files (FFF)" },
  },
  config = function()
    require("fff").setup({
      prompt = "> ",
      title = "Files",
      layout = {
        prompt_position = "bottom",
        preview_position = "right",
        flex = {
          size = 100,
          wrap = "top",
        },
      },
    })
  end,
}
