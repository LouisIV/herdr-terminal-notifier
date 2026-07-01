#!/usr/bin/env bash

notifier_source_app() {
  printf '%s/assets/HerdrNotify.app' "$ROOT"
}

notifier_source_bin() {
  printf '%s/Contents/MacOS/terminal-notifier' "$(notifier_source_app)"
}

notifier_source_info() {
  printf '%s/Contents/Info.plist' "$(notifier_source_app)"
}

notifier_source_icon() {
  printf '%s/Contents/Resources/Terminal.icns' "$(notifier_source_app)"
}

notifier_installed_app() {
  if [ -n "${HERDR_NOTIFY_APP_PATH:-}" ]; then
    printf '%s' "$HERDR_NOTIFY_APP_PATH"
  else
    printf '%s' "${HERDR_NOTIFY_INSTALL_DIR:-$HOME/Applications}/HerdrNotify.app"
  fi
}

notifier_installed_bin() {
  printf '%s/Contents/MacOS/terminal-notifier' "$(notifier_installed_app)"
}

notifier_lsregister() {
  printf '%s' "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
}

notifier_install_dir() {
  dirname "$(notifier_installed_app)"
}

notifier_needs_stage() {
  local dst_app dst_bin dst_info dst_icon
  dst_app="$(notifier_installed_app)"
  dst_bin="$(notifier_installed_bin)"
  dst_info="$dst_app/Contents/Info.plist"
  dst_icon="$dst_app/Contents/Resources/Terminal.icns"

  [ -d "$dst_app" ] || return 0
  [ -x "$dst_bin" ] || return 0
  [ -f "$dst_info" ] || return 0
  [ -f "$dst_icon" ] || return 0
  [ "$(notifier_source_bin)" -nt "$dst_bin" ] && return 0
  [ "$(notifier_source_info)" -nt "$dst_info" ] && return 0
  [ "$(notifier_source_icon)" -nt "$dst_icon" ] && return 0
  return 1
}

notifier_stage_app() {
  local src_app dst_app install_dir tmp_app
  src_app="$(notifier_source_app)"
  dst_app="$(notifier_installed_app)"
  install_dir="$(notifier_install_dir)"
  tmp_app="$install_dir/.HerdrNotify.app.tmp.$$"

  mkdir -p "$install_dir"
  rm -rf "$tmp_app"
  cp -R "$src_app" "$tmp_app"
  if ! codesign --force --deep -s - "$tmp_app" >/dev/null 2>&1; then
    echo "warning: failed to ad-hoc sign staged notifier: $tmp_app" >&2
  fi
  rm -rf "$dst_app"
  mv "$tmp_app" "$dst_app"
}

notifier_register_app() {
  local app quiet output status lsregister
  app="$1"
  quiet="${2:-0}"
  lsregister="$(notifier_lsregister)"

  if [ ! -x "$lsregister" ]; then
    [ "$quiet" = 1 ] || echo "warning: Launch Services registration tool missing: $lsregister" >&2
    return 1
  fi

  output="$("$lsregister" -f "$app" 2>&1)" || status=$?
  status="${status:-0}"
  if [ "$status" -ne 0 ]; then
    [ "$quiet" = 1 ] || {
      echo "warning: failed to register notifier with Launch Services: $app" >&2
      [ -n "$output" ] && echo "$output" >&2
    }
    return 1
  fi

  [ "$quiet" = 1 ] || echo "registered notifier: $app" >&2
  return 0
}

notifier_validate_app_launch() {
  local app quiet
  app="$1"
  quiet="${2:-0}"

  if ! open -g -n -a "$app" --args -version >/dev/null 2>&1; then
    [ "$quiet" = 1 ] || echo "warning: Launch Services still cannot launch notifier app: $app" >&2
    return 1
  fi

  return 0
}

notifier_prepare_app() {
  local state_dir quiet register_ttl sentinel sentinel_age app bin needs_register needs_stage
  state_dir="$1"
  quiet="${2:-0}"
  register_ttl="${REGISTER_TTL_SECONDS:-21600}"
  case "$register_ttl" in ''|*[!0-9]*) register_ttl=21600 ;; esac

  app="$(notifier_installed_app)"
  bin="$(notifier_installed_bin)"
  sentinel="$state_dir/.notifier-registered"
  needs_stage=0
  needs_register=0

  [ -d "$(notifier_source_app)" ] || return 1

  if notifier_needs_stage; then
    needs_stage=1
    needs_register=1
  fi

  if [ ! -x "$bin" ]; then
    needs_stage=1
    needs_register=1
  fi

  if [ ! -f "$sentinel" ] || [ "$bin" -nt "$sentinel" ]; then
    needs_register=1
  else
    sentinel_age=$(( $(date +%s) - $(stat -f %m "$sentinel" 2>/dev/null || echo 0) ))
    [ "$sentinel_age" -ge "$register_ttl" ] && needs_register=1
  fi

  if [ "$needs_stage" = 1 ]; then
    notifier_stage_app || return 1
    bin="$(notifier_installed_bin)"
  fi

  if [ "$needs_register" = 1 ]; then
    notifier_register_app "$app" "$quiet" || return 1
    notifier_validate_app_launch "$app" "$quiet" || return 1
    : >"$sentinel"
  fi

  printf '%s' "$app"
}
