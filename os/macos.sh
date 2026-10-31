#!/usr/bin/env bash

CONFIG_TARGETS=(
  "nvim::${HOME}/.config/nvim"
  "zed/settings.json::${HOME}/Library/Application Support/Zed/settings.json"
  "zed/keymap.json::${HOME}/Library/Application Support/Zed/keymap.json"
  "zed/snippets::${HOME}/Library/Application Support/Zed/snippets"
  "zed/themes::${HOME}/Library/Application Support/Zed/themes"
  ".wezterm.lua::${HOME}/.wezterm.lua"
  ".zshrc::${HOME}/.zshrc"
  ".aerospace.toml::${HOME}/.aerospace.toml"
  "karabiner/karabiner.json::${HOME}/.config/karabiner/karabiner.json"
  ".gitconfig::${HOME}/.gitconfig"
  "git/config-mir1t::${HOME}/.config/git/config-mir1t"
  "git/hooks/post-checkout::/Users/ivan/dev/work/new.editor.mir.1t.ru/.githooks/post-checkout"
  "ghostty/config::${HOME}/Library/Application Support/com.mitchellh.ghostty/config"
  ".agents/skills::${HOME}/.gemini/antigravity-cli/skills"
  ".agents/skills::${HOME}/.gemini/skills"
  ".agents/skills/yandex-games::${HOME}/.agents/skills/yandex-games"
  ".agents/skills/yandex-assets::${HOME}/.agents/skills/yandex-assets"
  ".agents/skills/vfx::${HOME}/.agents/skills/vfx"
)
