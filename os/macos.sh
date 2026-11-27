#!/usr/bin/env bash

CONFIG_TARGETS=(
  "nvim::${HOME}/.config/nvim"
  "zed/settings.json::${HOME}/Library/Application Support/Zed/settings.json"
  "zed/keymap.json::${HOME}/Library/Application Support/Zed/keymap.json"
  "zed/snippets::${HOME}/Library/Application Support/Zed/snippets"
  "zed/themes::${HOME}/Library/Application Support/Zed/themes"
  ".zshrc::${HOME}/.zshrc"
  ".aerospace.toml::${HOME}/.aerospace.toml"
  "karabiner/karabiner.json::${HOME}/.config/karabiner/karabiner.json"

  # Rex
  "rex/init.lua::${HOME}/.config/rex/init.lua"
  "rex/worktree.lua::${HOME}/.config/rex/worktree.lua"
  "bin/wt::${HOME}/.local/bin/wt"
  "bin/nvim-nav::${HOME}/.local/bin/nvim-nav"

  ".gitconfig::${HOME}/.gitconfig"
  "git/config-mir1t::${HOME}/.config/git/config-mir1t"
  "git/hooks/post-checkout::/Users/ivan/dev/work/new.editor.mir.1t.ru/.githooks/post-checkout"
  "ghostty/config::${HOME}/Library/Application Support/com.mitchellh.ghostty/config"

  # Gemini / Antigravity: runtime stays in ~/.gemini, only config is tracked
  "gemini/config/config.json::${HOME}/.gemini/config/config.json"
  "gemini/config/agents::${HOME}/.gemini/config/agents"
  "gemini/antigravity-cli/settings.json::${HOME}/.gemini/antigravity-cli/settings.json"
  "opencode/AGENTS.md::${HOME}/.gemini/AGENTS.md"
  ".agents/skills::${HOME}/.gemini/skills"
  ".agents/skills::${HOME}/.gemini/antigravity-cli/skills"
  ".agents/skills::${HOME}/.agents/skills"
)
