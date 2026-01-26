require("nvchad.configs.lspconfig").defaults()

local nvlsp = require "nvchad.configs.lspconfig"

local mason_path = vim.fn.stdpath "data" .. "/mason"
local tsdk_path = mason_path .. "/packages/typescript-language-server/node_modules/typescript/lib"

vim.lsp.config("ts_ls", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
})

vim.lsp.config("vue_ls", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  filetypes = { "vue" },
  init_options = {
    typescript = {
      tsdk = tsdk_path,
    },
  },
})

vim.lsp.config("gopls", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
})

vim.lsp.config("rust-analyzer", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
})

vim.lsp.enable { "ts_ls", "vue_ls", "gopls", "rust-analyzer" }

if vim.lsp.disable then
  vim.lsp.disable "vtsls"
end

-- Configure path and @/ alias resolution for gf command
vim.opt.path = { ".", "..", "src", "src/**" }
vim.opt.include = [[^import.*from.*['"]@\/]]

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "vue" },
  callback = function()
    vim.opt.include = [[^import.*from.*['"]@\/]]
    vim.opt.includeexpr = "substitute(v:fname,'@/','src/','g')"
  end,
})
--
-- -- vtsls for TypeScript and Vue support
-- vim.lsp.config("vtsls", {
--   filetypes = {
--     "typescript",
--     "typescriptreact",
--     "typescript.tsx",
--     "javascript",
--     "javascriptreact",
--     "vue",
--   },
--   settings = {
--     typescript = {
--       tsdk = vim.fn.expand "$VIMRUNTIME/lua/node_modules/typescript/lib",
--       inlayHints = {
--         includeInlayParameterNameHints = "all",
--         includeInlayFunctionParameterTypeHints = true,
--         includeInlayVariableTypeHints = true,
--         includeInlayPropertyDeclarationTypeHints = true,
--         includeInlayFunctionLikeReturnTypeHints = true,
--         includeInlayEnumMemberValueHints = true,
--       },
--     },
--     javascript = {
--       inlayHints = {
--         includeInlayParameterNameHints = "all",
--         includeInlayFunctionParameterTypeHints = true,
--         includeInlayVariableTypeHints = true,
--         includeInlayPropertyDeclarationTypeHints = true,
--         includeInlayFunctionLikeReturnTypeHints = true,
--         includeInlayEnumMemberValueHints = true,
--       },
--     },
--   },
-- })
--
-- -- Enable all LSP servers
-- vim.lsp.enable { "vtsls" }
