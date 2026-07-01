#!/usr/bin/env bash
# Stage the bundled HerdrNotify.app into a stable per-user app location and
# register it with Launch Services so macOS attributes notifications (and the
# herdr icon) to a consistent app identity.
#
# Runs as a herdr plugin [[build]] step on `herdr plugin install`, and is also
# safe to run by hand or from scripts/install.sh. Idempotent.
#
# Note: the one-time "Allow notifications" grant (System Settings -> Notifications
# -> herdr) cannot be scripted; the first notification will request it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/notifier.sh
. "$ROOT/lib/notifier.sh"

quiet=0
print_path=0
for arg in "$@"; do
  case "$arg" in
    --quiet) quiet=1 ;;
    --print-path) print_path=1 ;;
    *)
      echo "usage: scripts/setup-notifier.sh [--quiet] [--print-path]" >&2
      exit 2
      ;;
    esac
done

log() {
  [ "$quiet" = 1 ] || printf '[setup-notifier] %s\n' "$*"
}

warn() {
  printf '[setup-notifier] warning: %s\n' "$*" >&2
}

app_bundle_id() {
  local app="$1" plist="$1/Contents/Info.plist"
  [ -f "$plist" ] || return 0
  plutil -extract CFBundleIdentifier raw -o - "$plist" 2>/dev/null || true
}

dump_diagnostics() {
  local app="$1" bundle_id="" lsregister=""

  lsregister="$(notifier_lsregister)"
  bundle_id="$(app_bundle_id "$app")"

  warn "source app: $(notifier_source_app)"
  warn "installed app target: $(notifier_installed_app)"
  warn "launch services tool: $lsregister"
  [ -d "$(notifier_source_app)" ] && warn "source bundle exists: yes" || warn "source bundle exists: no"
  [ -d "$app" ] && warn "installed bundle exists: yes" || warn "installed bundle exists: no"
  [ -x "$(notifier_source_bin)" ] && warn "source binary exists: yes" || warn "source binary exists: no"
  [ -x "$(notifier_installed_bin)" ] && warn "installed binary exists: yes" || warn "installed binary exists: no"
  [ -n "$bundle_id" ] && warn "bundle id: $bundle_id"

  if [ -d "$app" ]; then
    codesign --verify --deep "$app" >&2 || true
    codesign -dv "$app" >&2 || true
  fi
}

[ -d "$(notifier_source_app)" ] || {
  warn "bundled notifier missing: $(notifier_source_app)"
  exit 0
}

state_dir="${HERDR_PLUGIN_STATE_DIR:-${TMPDIR:-/tmp}/herdr-tn}"
mkdir -p "$state_dir"

diag_log="$(mktemp "${TMPDIR:-/tmp}/herdr-notify-setup.XXXXXX")"
cleanup() {
  rm -f "$diag_log"
}
trap cleanup EXIT

if ! app_path="$(notifier_prepare_app "$state_dir" "$quiet" 2>"$diag_log")"; then
  warn "notifier install/registration failed"
  if [ -s "$diag_log" ]; then
    sed 's/^/[setup-notifier] /' "$diag_log" >&2 || true
  fi
  dump_diagnostics "$(notifier_installed_app)"
  exit 1
fi

if [ ! -x "$(notifier_installed_bin)" ]; then
  warn "notifier staged app is missing its executable"
  dump_diagnostics "$app_path"
  exit 1
fi

if [ "$print_path" = 1 ]; then
  printf '%s\n' "$app_path"
else
  log "notifier ready at $app_path"
fi
