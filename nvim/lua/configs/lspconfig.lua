require("nvchad.configs.lspconfig").defaults()
require("configs.lsp-fix") -- workaround for Neovim 0.12 LSP cursor out-of-range bug

local nvlsp = require "nvchad.configs.lspconfig"

-- Neovim 0.11+: отключение сервера = `vim.lsp.enable(name, false)`.
-- TS-серверы кроме tsrs выключены, иначе дублируются диагностики.
pcall(vim.lsp.enable, { "tsgo", "ts_ls", "vtsls" }, false)

local capabilities = vim.deepcopy(nvlsp.capabilities)
if
  capabilities.textDocument
  and capabilities.textDocument.completion
  and capabilities.textDocument.completion.completionItem
then
  capabilities.textDocument.completion.completionItem.commitCharactersSupport = false
end

local mason_path = vim.fn.stdpath "data" .. "/mason"
local packages_path = mason_path .. "/packages/typescript-language-server/node_modules"
local tsdk_path = packages_path .. "/typescript/lib"
local roblox_types_path = vim.fn.stdpath "config" .. "/types/globalTypes.d.luau"

-- tsrs — TypeScript LSP на Rust (вместо tsgo).
-- Установка: `bun add -g tsrs` (бинарь в ~/.bun/bin/tsrs).
local tsrs_path = vim.fn.exepath "tsrs"
if tsrs_path == "" then
  tsrs_path = vim.fn.expand "~/.bun/bin/tsrs"
end

vim.lsp.config("tsrs", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = { tsrs_path, "--lsp", "-stdio" },
  filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
})

vim.lsp.config("vue_ls", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
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
  capabilities = capabilities,
})

vim.lsp.config("rust_analyzer", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
})

vim.lsp.config("pyright", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
        autoImportCompletions = true,
        diagnosticMode = "workspace",
      },
    },
  },
})

vim.lsp.config("gdscript", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = vim.lsp.rpc.connect("127.0.0.1", 6005),
  filetypes = { "gd", "gdscript", "gdscript3" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local start_dir = fname ~= "" and vim.fs.dirname(fname) or vim.uv.cwd()
    local root = vim.fs.find({ "project.godot", ".git" }, {
      path = start_dir,
      upward = true,
    })[1]

    on_dir(root and vim.fs.dirname(root) or start_dir)
  end,
})

vim.lsp.config("clangd", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--fallback-flags=-std=c++20", -- standalone files without compile_commands.json
  },
})

vim.lsp.config("zls", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
})

vim.lsp.config("gleam", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = { "gleam", "lsp" },
  filetypes = { "gleam" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local start_dir = fname ~= "" and vim.fs.dirname(fname) or vim.uv.cwd()
    local root = vim.fs.find({ "gleam.toml", ".git" }, {
      path = start_dir,
      upward = true,
    })[1]

    on_dir(root and vim.fs.dirname(root) or start_dir)
  end,
})

vim.lsp.config("luau_lsp", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = { "luau-lsp", "lsp", "--definitions:@roblox=" .. roblox_types_path },
  filetypes = { "luau" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local start_dir = fname ~= "" and vim.fs.dirname(fname) or vim.uv.cwd()
    local root = vim.fs.find({ ".luaurc", "default.project.json", ".git" }, {
      path = start_dir,
      upward = true,
    })[1]

    on_dir(root and vim.fs.dirname(root) or start_dir)
  end,
  settings = {
    ["luau-lsp"] = {
      platform = {
        type = "roblox",
      },
      sourcemap = {
        enabled = true,
        autogenerate = true,
        sourcemapFile = "sourcemap.json",
        rojoProjectFile = "default.project.json",
        rojoPath = vim.fn.exepath "rojo",
      },
      completion = {
        imports = {
          enabled = true,
          suggestRequires = true,
        },
      },
    },
  },
})

vim.lsp.config("oxlint", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
})

vim.lsp.config("ols", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = { "ols" },
  filetypes = { "odin" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local start_dir = fname ~= "" and vim.fs.dirname(fname) or vim.uv.cwd()
    local root = vim.fs.find({ ".git" }, {
      path = start_dir,
      upward = true,
    })[1]
    on_dir(root and vim.fs.dirname(root) or start_dir)
  end,
})

vim.lsp.config("c3lsp", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = { "c3-lsp" },
  filetypes = { "c3", "c3i" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local start_dir = fname ~= "" and vim.fs.dirname(fname) or vim.uv.cwd()
    local root = vim.fs.find({ "project.json", ".git" }, {
      path = start_dir,
      upward = true,
    })[1]
    on_dir(root and vim.fs.dirname(root) or start_dir)
  end,
})

vim.lsp.config("v_analyzer", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = { mason_path .. "/packages/v-analyzer/v-analyzer" },
  filetypes = { "v", "vsh", "vv" },
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local start_dir = fname ~= "" and vim.fs.dirname(fname) or vim.uv.cwd()
    local root = vim.fs.find({ "v.mod", ".git" }, {
      path = start_dir,
      upward = true,
    })[1]
    on_dir(root and vim.fs.dirname(root) or start_dir)
  end,
  init_options = {
    customVrootPath = "/usr/lib/vlang",
  },
  settings = {
    v = {
      executablePath = "/usr/bin/v",
    },
  },
})

for _, server in ipairs {
  "vue_ls",
  "gopls",
  "rust_analyzer",
  "pyright",
  "clangd",
  "zls",
  "gdscript",
  "gleam",
  "c3lsp",
  "v_analyzer",
  "luau_lsp",
  "ols",
  "oxlint",
} do
  pcall(vim.lsp.enable, server)
end

-- tsrs включаем только если бинарь найден, иначе будет ошибка спавна на каждый TS-буфер
pcall(vim.lsp.enable, "tsrs", vim.uv.fs_stat(tsrs_path) ~= nil)
-- 0.12: vim.lsp.enable() авто-стартует на FileType, doautoall больше не нужен
-- Оставлен только для обратной совместимости с 0.11, в 0.12 можно удалить блок выше

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
