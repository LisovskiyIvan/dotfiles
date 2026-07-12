#!/usr/bin/env bash

CONFIG_TARGETS=(
  # Shell
  ".bashrc::${HOME}/.bashrc"

  # Git
  ".gitconfig::${HOME}/.gitconfig"

  # Tmux
  "tmux/tmux.conf::${HOME}/.config/tmux/tmux.conf"

  # Hyprland
  # "hypr::${HOME}/.config/hypr"



  # Ghostty
  "ghostty::${HOME}/.config/ghostty"


  # Omarchy hooks, extensions, branding (individual files — NOT whole omarchy dir)
  "omarchy/hooks/theme-set::${HOME}/.config/omarchy/hooks/theme-set"
)

# keyd is NOT auto-deployed — it requires sudo to write to /etc/keyd/
# See keyd/README.md for manual deployment instructions.
