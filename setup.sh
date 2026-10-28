#!/usr/bin/env bash
# Interactive dotfiles setup for macOS: Homebrew bundle -> config files (copy) -> mise install.
set -uo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/install-config.sh
. "$DOTFILES_DIR/scripts/install-config.sh"
# shellcheck source=scripts/apply-defaults.sh
. "$DOTFILES_DIR/scripts/apply-defaults.sh"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
RUN_ID=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$STATE_DIR/backups/$RUN_ID"
[ -e "$BACKUP_DIR" ] && BACKUP_DIR="$BACKUP_DIR-$$"
BACKUP_USED=0
LOG_FILE="$STATE_DIR/logs/$RUN_ID.log"
LOG_USED=0
NEXT_STEPS=''
CONFLICT_TOTAL=0
CONFLICT_INDEX=0
FAILED=0
SUMMARY=''

# Adds an item to "次にやること" in the final summary.
add_next() { NEXT_STEPS="$NEXT_STEPS$1
"; }

on_interrupt() {
  [ -t 0 ] && stty echo 2>/dev/null
  [ -n "$SPIN_PID" ] && kill "$SPIN_PID" 2>/dev/null
  printf '\r\033[2K'
  cleanup_temp
  gap
  warn "中断しました。処理済みのファイルはその状態のままで、書きかけのファイルは残っていません。"
  exit 130
}
trap on_interrupt INT TERM
trap cleanup_temp EXIT

# ------------------------------------------
# Homebrew
# ------------------------------------------

setup_homebrew() {
  heading "[1/5] Homebrew"
  local brew_bin p
  brew_bin=$(command -v brew 2>/dev/null || true)
  if [ -z "$brew_bin" ]; then
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$p" ] && brew_bin=$p && break
    done
  fi
  if [ -z "$brew_bin" ]; then
    warn "Homebrewがインストールされていません。"
    info "  公式のインストーラー（https://brew.sh）で入れます。途中でMacのパスワードを聞かれます。"
    info "  Xcode Command Line Tools（git など）も一緒に入ります。"
    if ui_confirm "Homebrewをインストールしますか？"; then
      info "  ここからはHomebrew公式インストーラーの画面です（英語）。"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$p" ] && brew_bin=$p && break
      done
    fi
    if [ -z "$brew_bin" ]; then
      warn "Homebrewがないため、Brewfileのパッケージのインストールを飛ばします。"
      return 0
    fi
  fi
  eval "$("$brew_bin" shellenv)"

  if brew bundle check --file="$DOTFILES_DIR/Brewfile" --no-upgrade >/dev/null 2>&1; then
    ok "Brewfile" "すべてインストール済みです"
    return 0
  fi

  local check_out missing names line
  check_out=$(brew bundle check --file="$DOTFILES_DIR/Brewfile" --no-upgrade --verbose 2>&1)
  # "→ Formula gum needs to be installed." -> "gum（コマンド）"
  missing=$(printf '%s\n' "$check_out" | awk '/needs to be installed/ {
    kind = ($2 == "Formula") ? "コマンド" : ($2 == "Cask") ? "アプリ" : $2
    printf "%s（%s）\n", $3, kind }')
  if [ -n "$missing" ]; then
    printf "$I"'%sBrewfileで不足しているもの（%d件）%s\n' "$C_BOLD" "$(printf '%s\n' "$missing" | wc -l | tr -d ' ')" "$C_RESET"
    printf '%s\n' "$missing" | while IFS= read -r line; do printf "$I"'  ・%s\n' "$line"; done
    if printf '%s\n' "$check_out" | grep -qi 'warning'; then
      info "  Homebrewの警告を省略しました。詳細は brew bundle check --verbose で確認できます。"
    fi
    names=$(printf '%s\n' "$missing" | sed 's/（.*//' | paste -sd '・' -)
  else
    printf "$I"'%sBrewfileで不足しているもの%s\n' "$C_BOLD" "$C_RESET"
    printf '%s\n' "$check_out" | while IFS= read -r line; do printf "$I"'  %s\n' "$line"; done
    names=''
  fi
  gap
  if ui_confirm "不足分を 'brew bundle install' でインストールしますか？"; then
    if run_quiet "Brewfileの不足分をインストール中" brew bundle install --file="$DOTFILES_DIR/Brewfile" --no-upgrade; then
      ok "Brewfile" "インストールしました${names:+（${names}）}"
    else
      err "brew bundle install が失敗しました。続行します。"
      show_log_tail
      FAILED=$((FAILED + 1))
    fi
  else
    info "  パッケージのインストールを飛ばしました。"
  fi
}

# ------------------------------------------
# Config files
# ------------------------------------------

config() {
  local label color
  PROGRESS=$3
  install_config "$DOTFILES_DIR/$1" "$2" || FAILED=$((FAILED + 1))
  PROGRESS=''
  case $RESULT in
    installed) label=新規配置; color=$C_BLUE ;;
    up-to-date) label=変更なし; color=$C_DIM ;;
    replaced) label=置き換え; color=$C_CYAN ;;
    merged) label=統合適用; color=$C_CYAN ;;
    kept) label=既存維持; color=$C_GREEN ;;
    skipped) label=スキップ; color=$C_YELLOW ;;
    *) label=処理失敗; color=$C_RED ;;
  esac
  SUMMARY="$SUMMARY${color}● $label$C_RESET  ~/$2
"
}

# <dotfiles path>|<install path relative to HOME>
CONFIGS='zsh/.zprofile|.zprofile
zsh/.zshrc|.zshrc
ghostty/config|.config/ghostty/config
ghostty/shaders/cursor_smear.glsl|.config/ghostty/shaders/cursor_smear.glsl
starship/starship.toml|.config/starship.toml
mise/config.toml|.config/mise/config.toml
macos/local.dotfiles.capslock-to-control.plist|Library/LaunchAgents/local.dotfiles.capslock-to-control.plist'

setup_configs() {
  local src rel new=0 same=0 conflicts=0 errors=0 n=0 total
  heading "[2/5] 設定ファイル — 全体の確認"
  info "  まだ何も変更しません。"
  gap
  while IFS='|' read -r src rel <&3; do
    case $(config_status "$DOTFILES_DIR/$src" "$rel") in
      new) printf "$I"'%s＋ 新規配置%s  ~/%s\n' "$C_BLUE" "$C_RESET" "$rel"; new=$((new + 1)) ;;
      same) printf "$I"'%s✓ 変更なし  ~/%s%s\n' "$C_DIM" "$rel" "$C_RESET"; same=$((same + 1)) ;;
      conflict) printf "$I"'%s▲ 競合あり%s  %s~/%s%s\n' "$C_YELLOW" "$C_RESET" "$C_BOLD" "$rel" "$C_RESET"; conflicts=$((conflicts + 1)) ;;
      *) printf "$I"'%s✗ 処理不可%s  ~/%s\n' "$C_RED" "$C_RESET" "$rel"; errors=$((errors + 1)) ;;
    esac
  done 3<<EOF
$CONFIGS
EOF
  gap; printf "$I"'%s新規 %d%s ・ %s変更なし %d%s ・ %s競合 %d%s ・ %s処理不可 %d%s\n' \
    "$C_BLUE" "$new" "$C_RESET" "$C_DIM" "$same" "$C_RESET" "$C_YELLOW" "$conflicts" "$C_RESET" "$C_RED" "$errors" "$C_RESET"
  [ "$conflicts" -gt 0 ] && info "  競合しているファイルは、このあと差分を表示して1件ずつ確認します。"
  CONFLICT_TOTAL=$conflicts
  CONFLICT_INDEX=0

  heading "[2/5] 設定ファイル — 適用"
  total=$(printf '%s\n' "$CONFIGS" | wc -l | tr -d ' ')
  while IFS='|' read -r src rel <&3; do
    n=$((n + 1))
    config "$src" "$rel" "$n/$total"
  done 3<<EOF
$CONFIGS
EOF
}

# ------------------------------------------
# mise
# ------------------------------------------

setup_mise() {
  heading "[3/5] mise"
  if ! command -v mise >/dev/null 2>&1; then
    warn "miseがインストールされていません（Brewfileに含まれています）。'mise install' を飛ばします。"
    return 0
  fi
  if [ ! -f "$HOME/.config/mise/config.toml" ]; then
    warn "~/.config/mise/config.toml がないため、'mise install' を飛ばします。"
    return 0
  fi
  if ui_confirm "~/.config/mise/config.toml の内容で 'mise install' を実行しますか？"; then
    if run_quiet "miseのツールをインストール中" sh -c 'cd "$HOME" && exec mise install'; then
      ok "mise" "ツールをインストールしました"
    else
      err "mise install が失敗しました。続行します。"
      show_log_tail
      FAILED=$((FAILED + 1))
    fi
  else
    info "  mise install を飛ばしました。"
  fi
}

# ------------------------------------------
# Apps (first-run setup)
# ------------------------------------------

# Apps that only need a sign-in when first used.
LOGIN_APPS='Cursor Slack Discord'

setup_orbstack() {
  local orb
  orb=$(command -v orb 2>/dev/null || true)
  [ -z "$orb" ] && [ -x /Applications/OrbStack.app/Contents/MacOS/bin/orb ] && orb=/Applications/OrbStack.app/Contents/MacOS/bin/orb
  [ -n "$orb" ] || return 0
  if [ "$("$orb" status 2>/dev/null)" = Running ]; then
    ok "OrbStack" "起動しています（docker などのコマンドが使えます）"
    return 0
  fi
  printf "$I"'%s●%s OrbStack  %s起動すると docker などのコマンドが使えるようになります。初回は管理者パスワードを聞かれることがあります。%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  if ui_confirm "OrbStackを起動しますか？（orb start）"; then
    if run_quiet "OrbStackを起動中" "$orb" start; then
      ok "OrbStack" "起動しました"
    else
      err "OrbStack の起動に失敗しました。アプリを開いて確認してください。"
      show_log_tail
    fi
  fi
}

setup_loop() {
  [ -d /Applications/Loop.app ] || return 0
  gap; printf "$I"'%s●%s Loop  %sウィンドウを動かすには、アクセシビリティの許可が必要です（macOSの仕様で、許可は手動のみ）。%s\n' "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  if ui_confirm "Loopを起動して、アクセシビリティの設定画面を開きますか？"; then
    open -a Loop || warn "Loop を開けませんでした。"
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || warn "設定画面を開けませんでした。"
    info "  開いた一覧で「Loop」をオンにしてください。"
  fi
  add_next "Loopのアクセシビリティを許可する（システム設定で「Loop」をオン。済んでいれば不要）"
}

# Adds sign-ins needed later to "次にやること".
add_logins() {
  local name apps=''
  for name in $LOGIN_APPS; do
    [ -d "/Applications/$name.app" ] && apps="$apps${apps:+・}$name"
  done
  [ -n "$apps" ] && add_next "${apps}：アプリを開いてログイン（使うときに）"
  if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
    add_next "GitHub CLI：gh auth login"
  fi
  command -v supabase >/dev/null 2>&1 && add_next "Supabase CLI：supabase login（使うときに）"
  return 0
}

setup_apps() {
  heading "[5/5] アプリの初期設定"
  setup_orbstack
  setup_loop
  add_logins

  [ -d /Applications/Ghostty.app ] || return 0
  gap
  if [ "${TERM_PROGRAM:-}" = ghostty ]; then
    info "  Ghosttyで新しいウィンドウを開くと、新しい設定（テーマ・フォント・starship）が反映されます。"
    add_next "Ghosttyで新しいウィンドウを開く（新しい設定を反映）"
  elif ui_confirm "Ghosttyを開きますか？（新しい設定とstarshipのプロンプトで使えます）"; then
    open -a Ghostty || warn "Ghostty を開けませんでした。"
  else
    add_next "Ghosttyを開く（新しい設定とstarshipのプロンプトで使える）"
  fi
}

# ------------------------------------------
# Main
# ------------------------------------------

intro "dotfiles セットアップ"
info "  $DOTFILES_DIR"

setup_homebrew
# gum (in the Brewfile) is picked up from here on once Homebrew installs it.
if ! command -v gum >/dev/null 2>&1; then
  info "  gumが見つからないため、番号入力で進めます（Brewfileのインストールで入ります）。"
fi
# Secret check before commits; only for a git clone (a ZIP/curl copy has no .git).
if [ -d "$DOTFILES_DIR/.git" ]; then
  git -C "$DOTFILES_DIR" config core.hooksPath .githooks
  info "  コミット前の機密情報チェック（gitleaks）を有効にしました。"
fi
setup_configs
setup_mise
setup_macos
setup_apps

# Prints a line inside the final summary box.
box_line() { printf '   %s│%s %s\n' "$C_DIM" "$C_RESET" "$1"; }

gap
if [ "$FAILED" -gt 0 ]; then
  printf '%s└%s  %s一部の処理が失敗しました%s\n' "$C_RED" "$C_RESET" "$C_BOLD$C_RED" "$C_RESET"
else
  printf '%s└%s  %s完了しました%s\n' "$C_GREEN" "$C_RESET" "$C_BOLD$C_GREEN" "$C_RESET"
fi
printf '\n   %s╭─ 結果%s\n' "$C_DIM" "$C_RESET"
printf '%s' "$SUMMARY" | while IFS= read -r line; do box_line "$line"; done
if [ "$BACKUP_USED" = 1 ] || [ "$LOG_USED" = 1 ]; then
  box_line ""
  [ "$BACKUP_USED" = 1 ] && box_line "バックアップ: $BACKUP_DIR"
  [ "$LOG_USED" = 1 ] && box_line "ログ: $LOG_FILE"
fi
if [ "$FAILED" -gt 0 ]; then
  box_line ""
  box_line "${C_RED}✗ ${FAILED}件の処理が失敗しました。上の ✗ を確認してから ./setup.sh を再実行してください。${C_RESET}"
fi
if [ -n "$NEXT_STEPS" ]; then
  box_line ""
  box_line "${C_BOLD}次にやること${C_RESET}"
  printf '%s' "$NEXT_STEPS" | while IFS= read -r line; do box_line " ・$line"; done
fi
printf '   %s╰────────────────────────────────────────%s\n\n' "$C_DIM" "$C_RESET"
[ "$FAILED" -gt 0 ] && exit 1
exit 0
