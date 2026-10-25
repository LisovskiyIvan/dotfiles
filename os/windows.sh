#!/usr/bin/env bash

# if command -v cygpath >/dev/null 2>&1; then
#   config_home="$(cygpath -u "${LOCALAPPDATA:-}")"
#   app_data="$(cygpath -u "${APPDATA:-}")"
#   user_home="$(cygpath -u "${USERPROFILE:-$HOME}")"
# else
  config_home="${LOCALAPPDATA:-}"
  app_data="${APPDATA:-}"
  user_home="${USERPROFILE:-$HOME}"
# fi

CONFIG_TARGETS=(
  "nvim::${config_home}/nvim"
  "zed/settings.json::${app_data}/Zed/settings.json"
  "zed/keymap.json::${app_data}/Zed/keymap.json"
  "zed/snippets::${app_data}/Zed/snippets"
  "zed/themes::${app_data}/Zed/themes"
  ".wezterm.lua::${user_home}/.wezterm.lua"
  ".zshrc::${user_home}/.zshrc"
)
