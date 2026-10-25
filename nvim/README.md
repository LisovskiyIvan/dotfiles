# nvim config

NvChad v2.5 + lazy.nvim. Нужен **Neovim >= 0.12** (используются `:restart`,
`vim.opt.autocomplete`, `vim.lsp.config`/`vim.lsp.enable`).

```sh
git clone <this repo> ~/.config/nvim
nvim   # lazy.nvim сам поставит плагины
```

## Ставится автоматически через Mason

Mason (`mason-lspconfig` + `mason-tool-installer`) при первом запуске ставит:

- LSP: `rust_analyzer`, `gopls`, `pyright`, `clangd`, `zls`, `oxlint`, `ols`
- форматтеры: `stylua`, `clang_format`

## Поставить вручную (вне nvim, Mason этого не умеет)

### Обязательное

- **tsrs** — TypeScript/JavaScript LSP вместо `tsgo`/`ts_ls`/`vtsls`
  (все три намеренно выключены). Бинарь ищется в `PATH`, затем `~/.bun/bin/tsrs`.

  ```sh
  bun add -g tsrs
  ```

  Без бинаря TS/JS останутся без LSP — ошибки не будет, сервер просто не включится.

- **goose** — компилятор Goose, он же LSP (`goose lsp`).
  Собрать по https://aardappel.github.io/goose/ и положить так, чтобы `stdlib/`
  лежал рядом с бинарём (например `~/.local/opt/goose/goose` + `~/.local/opt/goose/stdlib`).
  Конфиг сам ищет бинарь в `PATH`, `~/.local/opt/goose`, `~/.local/bin`,
  `/opt/homebrew/bin`, `/usr/local/bin`. Проверка: `:GooseLSP`.

  Для подсветки нужен tree-sitter-парсер из исходников goose:

  ```sh
  python3 ~/dev/myself/goose-src/tree-sitter/build.py
  ```

  Другой путь к `tree-sitter/` задаётся через `GOOSE_TREE_SITTER`.
  Без парсера работает `syntax/goose.vim` (fallback).

- **lazygit** — для `<leader>gg`, `lazygit.nvim`. `brew install lazygit`.

- **oxfmt** — форматтер JS/TS (conform). `brew install oxfmt` или `bun add -g oxfmt`.

- **black** — форматтер Python (conform). `uv tool install black` / `pipx install black`.
  Сейчас в `mason-tool-installer` его нет, поэтому без отдельной установки
  `python` молча не форматируется.

- **zig** — даёт `zigfmt` (conform). `brew install zig`.

### По языкам — только если язык нужен

- **gleam** — `brew install gleam`; LSP = `gleam lsp`.
- **ols** — Odin language server. Ставится Mason'ом, но сам компилятор Odin — отдельно.
- **C3** — `c3-lsp` из toolchain C3 (`c3c`).
- **Godot** — `gdscript` LSP не запускает процесс, а коннектится к `127.0.0.1:6005`.
  Нужен открытый редактор Godot 4 с включённым LSP (Editor Settings → Network → Language Server).
- **V** — `v-analyzer` ставится вручную и пропатчен (в Mason закомментирован,
  чтобы не перезаписался). В конфиге жёстко прописаны Linux-пути
  `/usr/lib/vlang` и `/usr/bin/v` — на macOS их надо править.
- **vue_ls** — нужен `typescript-language-server` в Mason (в `ensure_installed` его нет,
  но `tsdk` для `vue_ls` указывает в `~/.local/share/nvim/mason/packages/typescript-language-server`):

  ```vim
  :MasonInstall typescript-language-server
  ```

- **Luau / Roblox / Rojo** — удалены из конфига. Ничего ставить не нужно.

### Медиа (опционально)

- **image.nvim** (markdown-картинки): ImageMagick + luarocks
  (`brew install imagemagick luarocks`).
- **img-clip.nvim** (вставка картинки из буфера в markdown): macOS — `brew install pngpaste`;
  Wayland — `wl-clipboard`.
- **fff.nvim** при сборке скачивает готовый бинарь, fallback — `cargo build`.
- **ripgrep** — нужен telescope (NvChad) и удобен остальному; `brew install ripgrep`.

## Что ещё лишнее (кандидаты на удаление)

- `lua/config/remote_clipboard.lua` — модуль нигде не подключается (`require` отсутствует).
- `queries/vim/highlights.scm` — 361 строка вендорных queries для vim-парсера,
  перекрывают runtime-версию и давно не обновлялись.
- `syntax/goose.vim` — legacy fallback, дублирует `queries/goose/highlights.scm`;
  нужен только пока нет собранного tree-sitter-парсера.
- `snippets/typescript.json.bak` — бэкап-файл.
- Мёртвый код: закомментированный блок `vtsls` в конце `lua/configs/lspconfig.lua`,
  `-- test new blink`, закомментированные `m`/`M` в `lua/mappings.lua`.
- `go.nvim` с `lsp_cfg = true` — второй конфиг поверх `gopls` из `lspconfig.lua`
  (двойные настройки/диагностики).
- `codediff.nvim` объявлен дважды: отдельным spec и зависимостью Neogit.
- `telescope.nvim` в зависимостях Neogit — NvChad уже подключает telescope.
- `image.nvim` с `rocks.hererocks = true` — тяжёлая сборка Lua-роков ради картинок.
- `stylua` в `conform.lua` жёстко указывает на `mason/bin/stylua`; если stylua
  поставлен через brew/cargo, форматирование Lua сломается.

# Credits

1. Lazyvim starter https://github.com/LazyVim/starter — NvChad starter вдохновлён им.
