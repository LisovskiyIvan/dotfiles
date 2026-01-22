#!/usr/bin/env bash

config_home="${LOCALAPPDATA:-}"
app_data="${APPDATA:-}"
user_home="${USERPROFILE:-$HOME}"

CONFIG_TARGETS=(
  "nvim::${config_home}/nvim"
  "zed::${app_data}/Zed"
  ".wezterm.lua::${user_home}/.wezterm.lua"
)
