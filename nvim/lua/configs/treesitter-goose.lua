-- Local tree-sitter grammar for Goose.
-- Checkout of https://github.com/aardappel/goose; the grammar lives in tree-sitter/.
-- The generated parser is not checked in, so run this once (and after grammar
-- changes) before the editor can build it:
--
--   python3 ~/dev/myself/goose-src/tree-sitter/build.py
--
-- Point GOOSE_TREE_SITTER at the tree-sitter directory to use another checkout.
local M = {}

local notified = false

function M.register()
  local dir = vim.env.GOOSE_TREE_SITTER or vim.fn.expand "~/dev/myself/goose-src/tree-sitter"

  if vim.uv.fs_stat(dir .. "/src/parser.c") == nil then
    if not notified then
      notified = true
      vim.notify(
        "goose: tree-sitter parser not generated in " .. dir .. " (run python3 build.py there)",
        vim.log.levels.WARN
      )
    end
    return
  end

  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if not ok then
    return
  end

  parsers.get_parser_configs().goose = {
    install_info = {
      url = dir,
      files = { "src/parser.c", "src/scanner.c" },
    },
    filetype = "goose",
  }
end

return M
