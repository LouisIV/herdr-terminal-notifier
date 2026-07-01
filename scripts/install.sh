#!/usr/bin/env bash
# Idempotent install/link for the dot.terminal-notifier herdr plugin.
#
# Designed to be called from a declarative apply step, e.g.
#   - chezmoi:     run_onchange_install-herdr-tn.sh
#   - nix-darwin:  a system.activationScripts entry
# Re-running is a no-op once the plugin is registered. The bundled notifier app
# itself is staged into a stable per-user app location by scripts/setup-notifier.sh
# so Launch Services does not depend on the repo checkout path.
#
# Usage:
#   scripts/install.sh                 # install from GitHub (dot/herdr-terminal-notifier)
#   scripts/install.sh --link [PATH]   # link a local checkout (default: this repo)
set -euo pipefail

PLUGIN_ID="dot.terminal-notifier"
GITHUB_SLUG="dot/herdr-terminal-notifier"
HERDR="${HERDR_BIN_PATH:-herdr}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:---install}"

if ! command -v "$HERDR" >/dev/null 2>&1; then
  echo "herdr not found on PATH; skipping plugin install" >&2
  exit 0
fi

case "$mode" in
  --install|--link) ;;
  *)
    echo "usage: scripts/install.sh [--install|--link [PATH]]" >&2
    exit 2
    ;;
esac

plugin_list="$("$HERDR" plugin list 2>/dev/null || true)"
plugin_installed() {
  printf '%s\n' "$plugin_list" | grep -Fq -- "- $PLUGIN_ID "
}

case "$mode" in
  --link)
    path="${2:-$ROOT}"
    if plugin_installed && printf '%s\n' "$plugin_list" | grep -Fq -- "- $PLUGIN_ID " && printf '%s\n' "$plugin_list" | grep -Fq -- "[local:$path]"; then
      echo "$PLUGIN_ID already linked from $path"
    else
      echo "linking $PLUGIN_ID from $path"
      "$HERDR" plugin link "$path"
    fi
    ;;
  --install|*)
    if plugin_installed; then
      echo "$PLUGIN_ID already installed; refreshing notifier setup"
    else
      echo "installing $PLUGIN_ID from $GITHUB_SLUG"
      # --yes: required when stdin is non-interactive (CI / chezmoi / activation)
      "$HERDR" plugin install "$GITHUB_SLUG" --yes
    fi
    ;;
esac

if ! notifier_app="$(bash "$ROOT/scripts/setup-notifier.sh" --quiet --print-path)"; then
  echo "failed to stage/register the bundled notifier app" >&2
  exit 1
fi
echo "notifier ready at $notifier_app"

# jq is the only runtime dep (terminal-notifier is bundled as HerdrNotify.app).
command -v jq >/dev/null 2>&1 || echo "warning: 'jq' missing — add it to your Brewfile/homebrew.nix" >&2
