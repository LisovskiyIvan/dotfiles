#!/usr/bin/env bash

if command -v cygpath >/dev/null 2>&1; then
  config_home="$(cygpath -u "${LOCALAPPDATA:-}")"
  app_data="$(cygpath -u "${APPDATA:-}")"
  user_home="$(cygpath -u "${USERPROFILE:-$HOME}")"
else
  config_home="${LOCALAPPDATA:-}"
  app_data="${APPDATA:-}"
  user_home="${USERPROFILE:-$HOME}"
fi

CONFIG_TARGETS=(
  "nvim::${config_home}/nvim"
  "zed::${app_data}/Zed"
  ".wezterm.lua::${user_home}/.wezterm.lua"
)
