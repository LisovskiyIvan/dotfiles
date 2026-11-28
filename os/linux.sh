#!/usr/bin/env bash

CONFIG_TARGETS=(
  # Neovim
  "nvim::${HOME}/.config/nvim"

  # Shell
  ".bashrc::${HOME}/.bashrc"

  # Bin
  "bin/wt::${HOME}/.local/bin/wt"
  "bin/nvim-nav::${HOME}/.local/bin/nvim-nav"

  # Git
  ".gitconfig::${HOME}/.gitconfig"
  "git/config-mir1t::${HOME}/.config/git/config-mir1t"

  # Lazygit
  "lazygit/config.yml::${HOME}/.config/lazygit/config.yml"

  # Hyprland
  # "hypr::${HOME}/.config/hypr"



  # Ghostty
  "ghostty::${HOME}/.config/ghostty"

  # Chromium (render on the NVIDIA dGPU through XWayland)
  "chromium/chromium-flags.conf::${HOME}/.config/chromium-flags.conf"
  "chromium/environment.d.conf::${HOME}/.config/environment.d/90-nvidia-glx.conf"

  # Herdr (only config — runtime files like *.sock/*.log stay local)
  "herdr/config.toml::${HOME}/.config/herdr/config.toml"

  # Rex
  "rex/init.lua::${HOME}/.config/rex/init.lua"

  # Agents (opencode/crush compatible)
  ".agents::${HOME}/.agents"

  # Antigravity CLI (agy): skills + config, no macOS-specific files
  ".agents/skills::${HOME}/.gemini/skills"
  ".agents/skills::${HOME}/.gemini/antigravity-cli/skills"
  "gemini/antigravity-cli/settings.json::${HOME}/.gemini/antigravity-cli/settings.json"
  "gemini/config/agents::${HOME}/.gemini/config/agents"
  "opencode/AGENTS.md::${HOME}/.gemini/AGENTS.md"

  # Omarchy hooks, extensions, branding (individual files — NOT whole omarchy dir)
  "omarchy/hooks/theme-set::${HOME}/.config/omarchy/hooks/theme-set"

  # Opencode
  "opencode::${HOME}/.config/opencode"
)

# keyd is NOT auto-deployed — it requires sudo to write to /etc/keyd/
# See keyd/README.md for manual deployment instructions.
