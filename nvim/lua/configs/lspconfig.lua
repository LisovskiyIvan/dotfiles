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

-- goose — Goose Programming Language (aardappel/goose).
-- Компилер сам является языковым сервером: `goose lsp` говорит LSP по stdin/stdout.
-- Бинарь не в Mason, ставится вручную: https://aardappel.github.io/goose/
local function find_goose()
  local found = vim.fn.exepath "goose"
  if found ~= "" then
    return found
  end

  -- PATH не всегда содержит goose (nvim запущен не из login-шелла) — ищем вручную.
  for _, path in ipairs {
    vim.fn.expand "~/.local/opt/goose/goose",
    vim.fn.expand "~/.local/bin/goose",
    vim.fn.expand "~/.local/opt/goose/bin/goose",
    "/opt/homebrew/bin/goose",
    "/usr/local/bin/goose",
  } do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end

  return ""
end

local goose_path = find_goose()

-- stdlib лежит рядом с бинарём; если goose запущен из symlink/другого префикса —
-- передаём путь явно, иначе сервер не найдёт стандартную библиотеку.
local goose_cmd = { goose_path ~= "" and goose_path or "goose", "lsp" }
if goose_path ~= "" then
  local real = vim.uv.fs_realpath(goose_path) or goose_path
  local stdlib = vim.fs.joinpath(vim.fs.dirname(real), "stdlib")
  if vim.fn.isdirectory(stdlib) == 1 then
    goose_cmd = { goose_path, "lsp", "--stdlib", stdlib }
  end
end

-- root: ищем .git вверх, иначе берём каталог файла (иначе сервер не стартует)
local function goose_root(bufnr, on_dir)
  local fname = vim.api.nvim_buf_get_name(bufnr)
  local start_dir = fname ~= "" and vim.fs.dirname(fname) or vim.uv.cwd()
  local root = vim.fs.find({ ".git" }, {
    path = start_dir,
    upward = true,
  })[1]

  on_dir(root and vim.fs.dirname(root) or start_dir)
end

vim.lsp.config("goose", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = capabilities,
  cmd = goose_cmd,
  filetypes = { "goose" },
  root_dir = goose_root,
  -- Чтобы импортируемый модуль проверялся как часть программы, укажи entry-файл:
  -- init_options = { entryFiles = { "/abs/path/to/project/main.goose" } },
})

-- Бинарь не найден — говорим прямо, а не молча.
local goose_warned = false
local function goose_warn()
  if goose_path ~= "" or goose_warned then
    return
  end
  goose_warned = true
  vim.notify(
    "goose LSP: бинарь не найден. Установи из https://aardappel.github.io/goose/ "
      .. "или добавь ~/.local/opt/goose в PATH",
    vim.log.levels.WARN
  )
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "goose",
  callback = goose_warn,
})

-- :GooseLSP — диагностика (бинарь, клиент, диагностика)
vim.api.nvim_create_user_command("GooseLSP", function()
  local clients = vim.lsp.get_clients { name = "goose" }
  local lines = {
    "goose binary: " .. (goose_path ~= "" and goose_path or "NOT FOUND"),
    "enabled: " .. tostring(vim.lsp.is_enabled "goose"),
    "clients: " .. (#clients > 0 and "yes" or "no"),
    "filetype: " .. vim.bo.filetype,
    "diagnostics: " .. #vim.diagnostic.get(0),
  }
  print(table.concat(lines, "\n"))
end, {})

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
-- goose тоже не в Mason: включаем только если бинарь найден
if goose_path ~= "" then
  local ok, err = pcall(vim.lsp.enable, "goose")
  if not ok then
    vim.notify("goose LSP: " .. tostring(err), vim.log.levels.ERROR)
  end
end
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
