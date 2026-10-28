#!/usr/bin/env bash
# Sourced by setup.sh: applies macos/defaults.txt and macos/loop.plist, asking per differing item.
# Compatible with macOS /bin/bash 3.2. Needs install-config.sh (UI helpers) to be sourced first.

LOOP_DOMAIN=com.MrKai77.Loop
CAPSLOCK_LABEL=local.dotfiles.capslock-to-control

# Prints the current value in defaults.txt form (bool -> true/false); prints nothing when unset.
current_default() {
  local v
  v=$(defaults read "$1" "$2" 2>/dev/null) || return 0
  if [ "$3" = bool ]; then
    case $v in 1) v=true ;; 0) v=false ;; esac
  fi
  printf '%s' "$v"
}

# Prints a value for people: オン / オフ / （未設定）.
show_value() {
  case $1 in
    true) echo オン ;;
    false) echo オフ ;;
    '') echo "（未設定）" ;;
    *) echo "$1" ;;
  esac
}

# Prints the top-level keys of macos/loop.plist.
loop_keys() { grep -E $'^\t<key>' "$1" | sed 's/.*<key>\(.*\)<\/key>.*/\1/'; }

# Exports the current Loop settings to $1 (an empty plist when Loop has none yet).
export_loop() {
  defaults export "$LOOP_DOMAIN" "$1" 2>/dev/null && return 0
  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
    '<plist version="1.0">' '<dict/>' '</plist>' > "$1"
}

# Writes the managed Loop keys into Loop's settings, restarting Loop if it was running.
apply_loop() {
  local want=$1 current=$2 key running=0
  for key in $(loop_keys "$want"); do
    plutil -replace "$key" -xml "$(plutil -extract "$key" xml1 -o - "$want")" "$current" || return 1
  done
  # Loop writes its settings back when it quits, so stop it before importing.
  if pgrep -x Loop >/dev/null 2>&1; then
    running=1
    pkill -x Loop
    sleep 1
  fi
  defaults import "$LOOP_DOMAIN" "$current" || return 1
  [ "$running" = 1 ] && open -a Loop
  return 0
}

# Starts the Caps Lock -> Control agent now if it is installed but not loaded yet.
load_capslock_agent() {
  local plist="$HOME/Library/LaunchAgents/$CAPSLOCK_LABEL.plist"
  [ -f "$plist" ] || return 0
  launchctl print "gui/$(id -u)/$CAPSLOCK_LABEL" >/dev/null 2>&1 && return 0
  if launchctl bootstrap "gui/$(id -u)" "$plist"; then
    ok "Caps Lock" "Controlとして動くようにしました"
  else
    warn "Caps Lock の設定を読み込めませんでした。ログインし直すと反映されます。"
  fi
}

setup_macos() {
  local defs="$DOTFILES_DIR/macos/defaults.txt" loop_want="$DOTFILES_DIR/macos/loop.plist"
  local work domain key type value label cur key_list loop_diff='' n_same=0 n_diff=0
  local mode choice applied=0 dock=0 logout=0
  heading "[4/5] macOSとLoopの設定 — 全体の確認"
  info "  まだ何も変更しません。"
  gap

  work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-macos.XXXXXX") || return 1
  register_cleanup "$work"
  : > "$work/diff"
  while IFS='|' read -r domain key type value label <&3; do
    case $domain in '' | '#'*) continue ;; esac
    cur=$(current_default "$domain" "$key" "$type")
    if [ "$cur" = "$value" ]; then
      printf "$I"'%s✓ 変更なし  %s%s\n' "$C_DIM" "$label" "$C_RESET"
      n_same=$((n_same + 1))
    else
      printf "$I"'%s▲ 違う%s      %s  %sこのMac: %s → dotfiles: %s%s\n' "$C_YELLOW" "$C_RESET" "$label" \
        "$C_DIM" "$(show_value "$cur")" "$(show_value "$value")" "$C_RESET"
      printf '%s|%s|%s|%s|%s|%s\n' "$domain" "$key" "$type" "$value" "$label" "$cur" >> "$work/diff"
      n_diff=$((n_diff + 1))
    fi
  done 3< "$defs"

  export_loop "$work/loop.plist"
  key_list=$(loop_keys "$loop_want")
  for key in $key_list; do
    [ "$(plutil -extract "$key" xml1 -o - "$work/loop.plist" 2>/dev/null)" = "$(plutil -extract "$key" xml1 -o - "$loop_want")" ] ||
      loop_diff="$loop_diff $key"
  done
  if [ -z "$loop_diff" ]; then
    printf "$I"'%s✓ 変更なし  Loopの設定一式%s\n' "$C_DIM" "$C_RESET"
    n_same=$((n_same + 1))
  else
    printf "$I"'%s▲ 違う%s      Loopの設定一式  %s違う項目:%s%s\n' "$C_YELLOW" "$C_RESET" "$C_DIM" "$loop_diff" "$C_RESET"
    n_diff=$((n_diff + 1))
  fi
  gap; printf "$I"'%s変更なし %d%s ・ %s違う %d%s\n' "$C_DIM" "$n_same" "$C_RESET" "$C_YELLOW" "$n_diff" "$C_RESET"; gap

  heading "[4/5] macOSとLoopの設定 — 適用"
  if [ "$n_diff" -eq 0 ]; then
    ok "macOSとLoop" "すべてdotfilesと同じです"
  else
    mode=$(ui_choose "違う設定をどうしますか？" \
      "1つずつ選ぶ" \
      "すべてdotfilesに合わせる" \
      "何も変えない") || mode="何も変えない"

    if [ "$mode" != "何も変えない" ]; then
      while IFS='|' read -r domain key type value label cur <&3; do
        if [ "$mode" = "1つずつ選ぶ" ]; then
          choice=$(ui_choose "${label}（このMac: $(show_value "$cur") → dotfiles: $(show_value "$value")）" \
            "このMacのまま" "dotfilesに合わせる") || choice="このMacのまま"
          [ "$choice" = "dotfilesに合わせる" ] || continue
        fi
        if defaults write "$domain" "$key" "-$type" "$value"; then
          ok "$label" "$(show_value "$value") にしました"
          applied=$((applied + 1))
          [ "$domain" = com.apple.dock ] && dock=1 || logout=1
        else
          err "${label} を変更できませんでした。"
          FAILED=$((FAILED + 1))
        fi
      done 3< "$work/diff"

      if [ -n "$loop_diff" ]; then
        choice="dotfilesに合わせる"
        if [ "$mode" = "1つずつ選ぶ" ]; then
          choice=$(ui_choose "Loopの設定一式（違う項目:${loop_diff}）" \
            "このMacのまま" "dotfilesに合わせる") || choice="このMacのまま"
        fi
        if [ "$choice" = "dotfilesに合わせる" ]; then
          if apply_loop "$loop_want" "$work/loop.plist"; then
            ok "Loopの設定一式" "dotfilesに合わせました"
            applied=$((applied + 1))
          else
            err "Loop の設定を変更できませんでした。"
            FAILED=$((FAILED + 1))
          fi
        fi
      fi
    fi

    [ "$dock" = 1 ] && killall Dock 2>/dev/null
    if [ "$logout" = 1 ]; then
      info "  キーボード・文字入力・トラックパッドの設定は、ログアウトして入り直すと反映されます。"
      add_next "ログアウトして入り直す（キーボード・文字入力・トラックパッドの設定を反映）"
    fi
    [ "$applied" -eq 0 ] && info "  設定は変更していません。"
  fi
  SUMMARY="$SUMMARY${C_CYAN}● 設定反映${C_RESET}  macOSとLoop: ${applied}項目をdotfilesに合わせました
"

  load_capslock_agent
}
