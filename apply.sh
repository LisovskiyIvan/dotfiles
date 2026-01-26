#!/usr/bin/env bash
set -euo pipefail

MODE="copy"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode|-m)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Unknown аргумент: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "copy" && "$MODE" != "link" ]]; then
  echo "Mode должен быть copy или link" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

uname_out="$(uname -s)"
case "$uname_out" in
  Darwin)
    OS_SCRIPT="$REPO_ROOT/os/macos.sh"
    ;;
  Linux*)
    OS_SCRIPT="$REPO_ROOT/os/linux.sh"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    OS_SCRIPT="$REPO_ROOT/os/windows.sh"
    ;;
  *)
    echo "Unsupported OS: $uname_out" >&2
    exit 1
    ;;
esac

if [[ ! -f "$OS_SCRIPT" ]]; then
  echo "OS script not found: $OS_SCRIPT" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$OS_SCRIPT"

if [[ ${#CONFIG_TARGETS[@]} -eq 0 ]]; then
  echo "CONFIG_TARGETS is empty in $OS_SCRIPT" >&2
  exit 1
fi

backup_path() {
  local dest="$1"
  local parent
  local leaf
  local timestamp

  parent="$(dirname "$dest")"
  leaf="$(basename "$dest")"
  timestamp="$(date +"%Y%m%d-%H%M%S")"

  echo "$parent/$leaf.bak.$timestamp"
}

ensure_parent() {
  local dest="$1"
  local parent

  parent="$(dirname "$dest")"
  if [[ ! -d "$parent" ]]; then
    mkdir -p "$parent"
  fi
}

apply_target() {
  local source_rel="$1"
  local dest="$2"
  local source_path="$REPO_ROOT/$source_rel"

  if [[ ! -e "$source_path" ]]; then
    echo "Source path not found: $source_path" >&2
    exit 1
  fi

  ensure_parent "$dest"

  if [[ -e "$dest" || -L "$dest" ]]; then
    mv "$dest" "$(backup_path "$dest")"
  fi

  if [[ "$MODE" == "link" ]]; then
    ln -s "$source_path" "$dest"
    echo "Linked $source_rel -> $dest"
    return
  fi

  if [[ -d "$source_path" ]]; then
    cp -R "$source_path" "$dest"
    echo "Copied $source_rel -> $dest"
    return
  fi

  cp "$source_path" "$dest"
  echo "Copied $source_rel -> $dest"
}

for entry in "${CONFIG_TARGETS[@]}"; do
  source_rel="${entry%%::*}"
  dest="${entry#*::}"
  apply_target "$source_rel" "$dest"
done
