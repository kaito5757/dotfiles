#!/usr/bin/env bash
# Helpers sourced by setup.sh: UI prompts and install_config (copy one file with conflict handling).
# Compatible with macOS /bin/bash 3.2.

# ------------------------------------------
# Output (Catppuccin Mocha; plain text when not a terminal or NO_COLOR is set)
# ------------------------------------------

# Prints a color escape: 24-bit when the terminal supports it, otherwise the 256-color index.
_color() {
  local layer=$1 hex=$2 index=$3
  if [ "$TRUECOLOR" = 1 ]; then
    printf '\033[%s;2;%d;%d;%dm' "$layer" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
  else
    printf '\033[%s;5;%sm' "$layer" "$index"
  fi
}

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  case ${COLORTERM:-} in truecolor | 24bit) TRUECOLOR=1 ;; *) TRUECOLOR=0 ;; esac
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_DIM=$(_color 38 6c7086 243); C_RED=$(_color 38 f38ba8 211); C_GREEN=$(_color 38 a6e3a1 151)
  C_YELLOW=$(_color 38 f9e2af 223); C_BLUE=$(_color 38 89b4fa 111); C_CYAN=$(_color 38 94e2d5 116)
  C_MAUVE=$(_color 38 cba6f7 183)
  # Changed lines in diffs: light text on dark red / dark green backgrounds.
  C_DEL_LINE=$(_color 38 f5e0dc 224)$(_color 48 4b2c3a 52); C_ADD_LINE=$(_color 38 f5e0dc 194)$(_color 48 2d4636 22)
  # Same palette for gum menus (only where not set by the user).
  export GUM_CHOOSE_CURSOR_FOREGROUND=${GUM_CHOOSE_CURSOR_FOREGROUND:-"#cba6f7"}
  export GUM_CHOOSE_HEADER_FOREGROUND=${GUM_CHOOSE_HEADER_FOREGROUND:-"#cdd6f4"}
  export GUM_CHOOSE_SELECTED_FOREGROUND=${GUM_CHOOSE_SELECTED_FOREGROUND:-"#a6e3a1"}
  export GUM_CONFIRM_PROMPT_FOREGROUND=${GUM_CONFIRM_PROMPT_FOREGROUND:-"#cdd6f4"}
  export GUM_CONFIRM_SELECTED_BACKGROUND=${GUM_CONFIRM_SELECTED_BACKGROUND:-"#cba6f7"}
  export GUM_CONFIRM_SELECTED_FOREGROUND=${GUM_CONFIRM_SELECTED_FOREGROUND:-"#1e1e2e"}
else
  TRUECOLOR=0
  C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_MAUVE=''
  C_DEL_LINE=''; C_ADD_LINE=''
fi

# The vertical rail on the left (Clack style) and the indent for lines on it.
RAIL="${C_DIM}│${C_RESET}"
I="$RAIL  "

# Prints the opening line of the session.
intro() { printf '\n%s┌%s  %s%s%s\n' "$C_DIM" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }

# Prints an empty line on the rail.
gap() { printf '%s\n' "$RAIL"; }

# Prints a section heading on the rail.
heading() { gap; printf '%s◆%s  %s%s%s\n' "$C_MAUVE" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }

# Prints a success line: path and a dimmed detail ([n/total] when PROGRESS is set).
ok() { printf '%s%s✓%s %s%s  %s%s%s\n' "$I" "$C_GREEN" "$C_RESET" "${PROGRESS:+$C_DIM[$PROGRESS]$C_RESET }" "$1" "$C_DIM" "$2" "$C_RESET"; }

# Prints a warning line.
warn() { printf '%s%s⚠%s %s\n' "$I" "$C_YELLOW" "$C_RESET" "$1"; }

# Prints an error line to stderr.
err() { printf '%s%s✗%s %s\n' "$I" "$C_RED" "$C_RESET" "$1" >&2; }

# Prints a dimmed informational line (leading spaces in the message are dropped).
info() { printf '%s%s%s%s\n' "$I" "$C_DIM" "${1#  }" "$C_RESET"; }

# ------------------------------------------
# Prompts (gum if available, otherwise read)
# ------------------------------------------

# Prints an answered question: "◇ question" + answer when the prompt was folded away (collapse=1),
# otherwise only the answer under the prompt that is still on screen.
_answered() {
  if [ "$3" = 1 ]; then
    printf '%s◇%s  %s\n%s%s%s%s\n' "$C_GREEN" "$C_RESET" "$1" "$I" "$C_DIM" "$2" "$C_RESET" >&2
  else
    printf '%s%s→ %s%s\n' "$I" "$C_GREEN" "$2" "$C_RESET" >&2
  fi
}

# Prints the display width of a string (wide characters such as Japanese count as 2).
_width() {
  local chars bytes
  chars=$(printf '%s' "$1" | wc -m | tr -d ' ')
  bytes=$(printf '%s' "$1" | LC_ALL=C wc -c | tr -d ' ')
  # Wide characters are 3 bytes in UTF-8; each adds one column beyond its character count.
  echo $((chars + (bytes - chars) / 2))
}

# Number of terminal rows and columns (24 x 80 when unknown).
_term_size() { stty size </dev/tty 2>/dev/null || echo "24 80"; }

# True when every given line fits the terminal width (wide characters counted as 2 columns).
_fits() {
  local cols line
  cols=$(_term_size | awk '{ print $2 }')
  for line in "$@"; do
    [ $(( $(_width "$line") + 16 )) -lt "$cols" ] || return 1
  done
}

# Shows stdin directly when it fits the screen, otherwise in less.
pager() {
  local text rows
  text=$(cat)
  rows=$(_term_size | awk '{ print $1 }')
  # Unknown size (0 rows) also prints directly so nothing waits for a key.
  if [ ! -t 1 ] || [ "${rows:-0}" -le 8 ] || [ "$(printf '%s\n' "$text" | wc -l)" -lt $((rows - 8)) ]; then
    printf '%s\n' "$text"
  else
    printf '%s\n' "$text" | LESSCHARSET=utf-8 less -RX
  fi
}

# Prints the chosen option; returns non-zero when cancelled (Esc / EOF).
# On a terminal the menu is folded into the answer once chosen.
ui_choose() {
  local prompt=$1; shift
  local answer i=1 opt rows collapse=0
  if command -v gum >/dev/null 2>&1 && [ -t 0 ]; then
    answer=$(gum choose --header "$prompt" "$@") || return 1
    _answered "$prompt" "$answer" 1
    printf '%s\n' "$answer"
    return 0
  fi
  [ -t 0 ] && [ -t 2 ] && _fits "$prompt" "$@" && collapse=1
  printf '%s◆%s  %s%s%s\n' "$C_MAUVE" "$C_RESET" "$C_BOLD" "$prompt" "$C_RESET" >&2
  for opt in "$@"; do
    printf '%s  %s%d%s  %s\n' "$I" "$C_BOLD$C_MAUVE" "$i" "$C_RESET" "$opt" >&2
    i=$((i + 1))
  done
  rows=$((1 + $#))
  while :; do
    printf '%s%s›%s 番号を押す [1-%d]（Enterで1）: ' "$I" "$C_MAUVE" "$C_RESET" "$#" >&2
    # On a terminal one key decides (shown by us, so type-ahead cannot shift the lines).
    if [ -t 0 ]; then
      IFS= read -r -s -n 1 answer || { printf '\n' >&2; return 1; }
      # Ctrl-D cancels, as EOF does in line mode.
      [ "$answer" = $'\004' ] && { printf '\n' >&2; return 1; }
      printf '%s\n' "$answer" >&2
    else
      IFS= read -r answer || { printf '\n' >&2; return 1; }
      printf '\n' >&2
    fi
    rows=$((rows + 1))
    [ -z "$answer" ] && answer=1
    case $answer in
      *[!0-9]*) ;;
      *)
        if [ "$answer" -ge 1 ] && [ "$answer" -le "$#" ]; then
          shift $((answer - 1))
          [ "$collapse" = 1 ] && printf '\033[%dA\033[J' "$rows" >&2
          _answered "$prompt" "$1" "$collapse"
          printf '%s\n' "$1"
          return 0
        fi
        ;;
    esac
    printf '%s%s無効な番号です。%s\n' "$I" "$C_RED" "$C_RESET" >&2
    rows=$((rows + 1))
  done
}

# Returns 0 on yes; defaults to no (including EOF).
ui_confirm() {
  local answer yes=1 collapse=0
  if command -v gum >/dev/null 2>&1 && [ -t 0 ]; then
    gum confirm --default=false "$1" && yes=0
    collapse=1
  else
    printf '%s%s?%s %s %s[y/N]%s: ' "$I" "$C_MAUVE" "$C_RESET" "$1" "$C_DIM" "$C_RESET" >&2
    if [ -t 0 ]; then
      IFS= read -r -s -n 1 answer || answer=''
      [ "$answer" = $'\004' ] && answer=''
      printf '%s\n' "$answer" >&2
    else
      IFS= read -r answer || answer=''
      printf '\n' >&2
    fi
    case $answer in [yY] | [yY][eE][sS]) yes=0 ;; esac
    if [ -t 0 ] && [ -t 2 ] && _fits "$1"; then
      printf '\033[1A\033[J' >&2
      collapse=1
    fi
  fi
  if [ "$yes" = 0 ]; then _answered "$1" "はい" "$collapse"; else _answered "$1" "いいえ" "$collapse"; fi
  return "$yes"
}

# ------------------------------------------
# Spinner (long commands run quietly; full output goes to LOG_FILE)
# ------------------------------------------

SPIN_PID=''

# Runs a command with a spinner; output is appended to LOG_FILE. Returns the command's status.
run_quiet() {
  local title=$1; shift
  local frames i=0 rc start=$SECONDS
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '\n==== %s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
  LOG_USED=1
  if [ ! -t 2 ]; then
    printf '%s%s…\n' "$I" "$title" >&2
    "$@" >> "$LOG_FILE" 2>&1
    return
  fi
  frames=(◒ ◐ ◓ ◑)
  "$@" >> "$LOG_FILE" 2>&1 &
  SPIN_PID=$!
  while kill -0 "$SPIN_PID" 2>/dev/null; do
    printf '\r\033[2K%s%s%s  %s… %s(%d秒)%s' "$C_MAUVE" "${frames[i % 4]}" "$C_RESET" "$title" "$C_DIM" $((SECONDS - start)) "$C_RESET" >&2
    i=$((i + 1))
    sleep 0.2
  done
  wait "$SPIN_PID"; rc=$?
  SPIN_PID=''
  printf '\r\033[2K' >&2
  return "$rc"
}

# Prints the last lines of LOG_FILE (secrets masked) after a failed run_quiet.
show_log_tail() {
  local line
  info "  ログの最後の部分（全体: ${LOG_FILE}）"
  tail -n "${1:-15}" "$LOG_FILE" | mask_secrets | while IFS= read -r line; do
    printf '%s  %s%s%s\n' "$I" "$C_DIM" "$line" "$C_RESET"
  done
}

# ------------------------------------------
# File operations
# ------------------------------------------

# Temp files/dirs to remove on exit or interrupt (newline separated).
CLEANUP_PATHS=''

cleanup_temp() {
  local p
  while IFS= read -r p; do
    [ -n "$p" ] && rm -rf "$p"
  done <<EOF
$CLEANUP_PATHS
EOF
  CLEANUP_PATHS=''
}

register_cleanup() { CLEANUP_PATHS="$CLEANUP_PATHS$1
"; }

# Replaces values that look like secrets with [伏せ字] (display only; files are never changed).
mask_secrets() {
  perl -pe '
    BEGIN { $m = "[伏せ字]" }
    # Inside a private key block, or a bare base64 line (a key chunk shown out of its block).
    if (/-----BEGIN [A-Z ]*PRIVATE KEY-----/) { $in_key = 1; next }
    if (/-----END [A-Z ]*PRIVATE KEY-----/) { $in_key = 0; next }
    if ($in_key || /^.?\s*[A-Za-z0-9+\/]{40,}={0,2}\s*$/) { s/^(.?\s*).*$/$1$m/; next }
    # Values assigned to names like *_TOKEN, password, api_key ...
    s/((?:token|secret|passw(?:or)?d|api[_-]?key|access[_-]?key|private[_-]?key|credential|auth)\w*["\x27]?\s*[:=]\s*)(["\x27]?)[^"\x27\s#]+/$1$2$m/gi;
    # Well-known token formats anywhere in the line.
    s/\b(gh[pousr]_|github_pat_)\w{10,}/$1$m/g;
    s/\b(sk-(?:ant-|proj-)?)[\w-]{16,}/$1$m/g;
    s/\b(xox[abprs]-)[\w-]{10,}/$1$m/g;
    s/\bAKIA[0-9A-Z]{16}\b/AKIA$m/g;
    s/\bAIza[\w-]{35}/AIza$m/g;
    s/\beyJ[\w-]{10,}\.[\w-]{10,}\.[\w-]{10,}/$m/g;
  '
}

# Renders `diff -u` output from stdin: colored lines, "N行目付近" instead of @@ headers.
render_diff() {
  # Tags must have the same display width (8 columns).
  local old_tag=$1 new_tag=$2 old_desc=$3 new_desc=$4
  printf "$I"'%s■ %s%s（%s）   %s■ %s%s（%s）   %s色なし: 共通の行%s\n' \
    "$C_RED" "${old_tag% }" "$C_RESET" "$old_desc" "$C_GREEN" "$new_tag" "$C_RESET" "$new_desc" "$C_DIM" "$C_RESET"
  # Leading context lines are held back so the header can show the first changed line.
  awk -v old_tag="$old_tag" -v new_tag="$new_tag" -v red="$C_RED$C_BOLD" -v green="$C_GREEN$C_BOLD" \
      -v del_line="$C_DEL_LINE" -v add_line="$C_ADD_LINE" -v cyan="$C_CYAN" -v dim="$C_DIM" -v reset="$C_RESET" -v rail="$RAIL" -v ind="$I" '
    NR <= 2 && /^(---|\+\+\+) / { next }
    /^@@/ { split($2, a, ","); start = substr(a[1], 2) + 0; held = ""; nheld = 0; found = 0; next }
    /^\\/ { next }
    /^[-+]/ {
      if (!found) {
        n = start + nheld; if (n < 1) n = 1
        printf "%s\n%s%s── %d行目 ──%s\n%s", rail, ind, cyan, n, reset, held
        found = 1
      }
      text = substr($0, 2)
      if (substr($0, 1, 1) == "-") { tag = old_tag; tc = red; lc = del_line } else { tag = new_tag; tc = green; lc = add_line }
      if (text == "") printf "%s%s%s%s %s│%s %s（空行）%s\n", ind, tc, tag, reset, dim, reset, dim, reset
      else printf "%s%s%s%s %s│%s %s%s%s\n", ind, tc, tag, reset, dim, reset, lc, text, reset
      next
    }
    {
      line = sprintf("%s         %s│ %s%s\n", ind, dim, substr($0, 2), reset)
      if (found) printf "%s", line; else { held = held line; nheld++ }
    }
  '
}

# Shows the diff of existing (dest) vs dotfiles (src).
show_diff() {
  local dest=$1 src=$2
  local left=$dest
  [ -e "$dest" ] || left=/dev/null
  diff -u "$left" "$src" | mask_secrets | render_diff "このMac " "dotfiles" "今の設定" "リポジトリの設定" | pager
  return 0
}

# Backs up dest (file or symlink) under BACKUP_DIR keeping its path relative to HOME.
backup_file() {
  local dest=$1 rel=$2
  local backup="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$backup")" || return 1
  if [ -L "$dest" ]; then
    ln -s "$(readlink "$dest")" "$backup" || return 1
  else
    cp -p "$dest" "$backup" || return 1
  fi
  BACKUP_USED=1
  info "  バックアップ: $backup"
}

# Atomically writes content of $1 to $2 (temp file in the same dir, then mv).
atomic_copy() {
  local from=$1 dest=$2 tmp mode
  tmp=$(mktemp "$(dirname "$dest")/.$(basename "$dest").dotfiles.XXXXXX") || return 1
  register_cleanup "$tmp"
  mode=$(stat -f '%Lp' "$from") || return 1
  cp "$from" "$tmp" && chmod "$mode" "$tmp" && mv -f "$tmp" "$dest"
}

# Backs up dest then replaces it with the content of $from.
replace_with() {
  local from=$1 dest=$2 rel=$3
  if [ ! -w "$(dirname "$dest")" ]; then
    err "書き込み権限がありません: $(dirname "$dest")"
    return 1
  fi
  backup_file "$dest" "$rel" || { err "バックアップに失敗しました。~/$rel は変更していません"; return 1; }
  atomic_copy "$from" "$dest" || { err "コピーに失敗しました。~/$rel は変更していません"; return 1; }
}

# Prints lines from stdin with a side tag, the same style as render_diff.
print_tagged() {
  local tag=$1 tag_color=$2 line_color=$3 line
  while IFS= read -r line || [ -n "$line" ]; do
    if [ -z "$line" ]; then
      printf "$I"'%s%s%s %s│%s %s（空行）%s\n' "$tag_color" "$tag" "$C_RESET" "$C_DIM" "$C_RESET" "$C_DIM" "$C_RESET"
    else
      printf "$I"'%s%s%s %s│%s %s%s%s\n' "$tag_color" "$tag" "$C_RESET" "$C_DIM" "$C_RESET" "$line_color" "$line" "$C_RESET"
    fi
  done
}

# Lists differing blocks of `diff old new` as "type old_from old_to new_from new_to".
list_hunks() {
  diff "$1" "$2" | awk '/^[0-9]+(,[0-9]+)?[acd][0-9]+(,[0-9]+)?$/ {
    match($0, /[acd]/); t = substr($0, RSTART, 1)
    split(substr($0, 1, RSTART - 1), a, ","); split(substr($0, RSTART + 1), b, ",")
    print t, a[1], (a[2] == "" ? a[1] : a[2]), b[1], (b[2] == "" ? b[1] : b[2]) }'
}

# Writes the merged file to stdout: old/new/hunks files plus one choice per hunk (o = old, n = new, b = both).
build_merged() {
  local old=$1 new=$2 hunks=$3 choices=$4
  awk -v choices="$choices" -v old_nl="$(tail -c1 "$old" | wc -l | tr -d ' ')" \
      -v new_nl="$(tail -c1 "$new" | wc -l | tr -d ' ')" -v f1="$old" -v f2="$new" '
    FILENAME == f1 { old[++no] = $0; next }
    FILENAME == f2 { nw[++nn] = $0; next }
    { ht[++nh] = $1; o1[nh] = $2; o2[nh] = $3; n1[nh] = $4; n2[nh] = $5 }
    function emit(src, i) {
      if (have) printf "%s\n", pending
      pending = (src == "o") ? old[i] : nw[i]; have = 1; last_src = src; last_i = i
    }
    END {
      cur = 1
      for (h = 1; h <= nh; h++) {
        c = substr(choices, h, 1)
        if (ht[h] == "a") {
          for (; cur <= o1[h]; cur++) emit("o", cur)
          if (c != "o") for (i = n1[h]; i <= n2[h]; i++) emit("n", i)
        } else {
          for (; cur < o1[h]; cur++) emit("o", cur)
          if (c == "o" || c == "b") for (i = o1[h]; i <= o2[h]; i++) emit("o", i)
          if (ht[h] == "c" && c != "o") for (i = n1[h]; i <= n2[h]; i++) emit("n", i)
          cur = o2[h] + 1
        }
      }
      for (; cur <= no; cur++) emit("o", cur)
      if (have) {
        # Keep "no newline at end of file" from whichever file the last line came from.
        nl = (last_src == "o") ? (last_i < no || old_nl) : (last_i < nn || new_nl)
        printf "%s%s", pending, (nl ? "\n" : "")
      }
    }' "$old" "$new" "$hunks"
}

# Merges block by block in the terminal; applies only after confirmation.
# Returns 0 when applied, 2 when cancelled (caller goes back to the menu), 1 on error.
merge_in_terminal() {
  local src=$1 dest=$2 rel=$3
  local work total h choices choice t ofrom oto nfrom nto line_no
  work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-merge.XXXXXX") || return 1
  register_cleanup "$work"
  list_hunks "$dest" "$src" > "$work/hunks"
  total=$(wc -l < "$work/hunks" | tr -d ' ')

  while :; do
    choices='' h=0
    while read -r t ofrom oto nfrom nto <&4; do
      h=$((h + 1))
      line_no=$ofrom; [ "$t" = a ] && line_no=$((ofrom + 1))
      gap; printf "$I"'%s── 統合 %d/%d か所目（%d行目）──%s\n' "$C_CYAN" "$h" "$total" "$line_no" "$C_RESET"
      [ "$t" != a ] && sed -n "${ofrom},${oto}p" "$dest" | mask_secrets | print_tagged "このMac " "$C_RED$C_BOLD" "$C_DEL_LINE"
      [ "$t" != d ] && sed -n "${nfrom},${nto}p" "$src" | mask_secrets | print_tagged "dotfiles" "$C_GREEN$C_BOLD" "$C_ADD_LINE"
      gap
      case $t in
        c) choice=$(ui_choose "この部分はどちらにしますか？" \
             "このMacの内容を使う" "dotfilesの内容を使う" "両方残す（このMac → dotfiles の順）") || return 2 ;;
        a) choice=$(ui_choose "dotfilesにだけある行です。どうしますか？" \
             "追加しない（このMacのまま）" "追加する（dotfilesに合わせる）") || return 2 ;;
        d) choice=$(ui_choose "このMacにだけある行です。どうしますか？" \
             "残す（このMacのまま）" "削除する（dotfilesに合わせる）") || return 2 ;;
      esac
      case $choice in
        "このMac"* | "追加しない"* | "残す"*) choices="${choices}o" ;;
        "両方"*) choices="${choices}b" ;;
        *) choices="${choices}n" ;;
      esac
    done 4< "$work/hunks"

    build_merged "$dest" "$src" "$work/hunks" "$choices" > "$work/merged"
    if cmp -s "$work/merged" "$dest"; then
      info "  選んだ結果は、このMacの今の設定と同じです（変更なし）。"
      return 2
    fi
    chmod "$(stat -f '%Lp' "$dest")" "$work/merged"

    gap; printf "$I"'%s~/%s に適用される変更%s\n' "$C_BOLD" "$rel" "$C_RESET"; gap
    diff -u "$dest" "$work/merged" | mask_secrets | render_diff "このMac " "統合結果" "今の設定" "適用される内容" | pager
    gap

    choice=$(ui_choose "この内容で ~/$rel に適用しますか？" \
      "適用する（バックアップあり）" \
      "選び直す" \
      "統合をやめる（変更しない）") || choice="統合をやめる（変更しない）"
    case $choice in
      "適用する"*)
        replace_with "$work/merged" "$dest" "$rel" || return 1
        return 0
        ;;
      "選び直す") ;;
      *) return 2 ;;
    esac
  done
}

# Prints what install_config would do, without changing anything: new, same, conflict, or error.
config_status() {
  local src=$1 dest="$HOME/$2"
  if [ ! -f "$src" ] || [ -d "$dest" ]; then
    echo error
  elif [ -e "$dest" ] && [ ! -L "$dest" ] && [ ! -f "$dest" ]; then
    echo error
  elif [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    echo new
  elif [ -e "$dest" ] && [ ! -r "$dest" ]; then
    echo error
  elif [ -e "$dest" ] && cmp -s "$dest" "$src"; then
    echo same
  else
    echo conflict
  fi
}

# ------------------------------------------
# install_config <src (absolute)> <dest relative to HOME>
# Sets RESULT to one of: installed, up-to-date, replaced, merged, kept, skipped, failed.
# ------------------------------------------

install_config() {
  local src=$1 rel=$2
  local dest="$HOME/$rel" dest_dir choice options_kind
  dest_dir=$(dirname "$dest")
  RESULT=failed

  if [ ! -f "$src" ]; then
    err "dotfiles側のファイルが見つかりません: $src"
    return 1
  fi

  # Unsupported destination types: never touched.
  if [ -d "$dest" ]; then
    err "~/$rel はディレクトリのためスキップしました（配置するには手動で移動してください）。"
    return 1
  fi
  if [ -e "$dest" ] && [ ! -L "$dest" ] && [ ! -f "$dest" ]; then
    err "~/$rel は通常のファイルではないためスキップしました。"
    return 1
  fi

  # Case A: does not exist (a dangling symlink counts as existing).
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    if ! mkdir -p "$dest_dir" 2>/dev/null; then
      err "ディレクトリを作成できません: $dest_dir"
      return 1
    fi
    if [ ! -w "$dest_dir" ]; then
      err "書き込み権限がありません: $dest_dir"
      return 1
    fi
    atomic_copy "$src" "$dest" || { err "コピーに失敗しました: ~/$rel"; return 1; }
    ok "~/$rel" "新しく配置しました"
    RESULT=installed
    return 0
  fi

  if [ -e "$dest" ] && [ ! -r "$dest" ]; then
    err "読み取り権限がないためスキップしました: ~/$rel"
    return 1
  fi

  # Case B: identical content (also via symlink).
  if [ -e "$dest" ] && cmp -s "$dest" "$src"; then
    if [ -L "$dest" ]; then
      ok "~/$rel" "最新です（シンボリックリンク -> $(readlink "$dest")）"
    else
      ok "~/$rel" "最新です"
    fi
    RESULT=up-to-date
    return 0
  fi

  # Case C: differs.
  local title=競合 hunks reason
  CONFLICT_INDEX=$((${CONFLICT_INDEX:-0} + 1))
  [ "${CONFLICT_TOTAL:-0}" -gt 0 ] && title="競合 $CONFLICT_INDEX/$CONFLICT_TOTAL"
  if [ -L "$dest" ]; then
    if [ -d "$dest" ]; then
      err "~/$rel はディレクトリへのシンボリックリンクのためスキップしました。"
      return 1
    fi
    reason="既存のパスはシンボリックリンクです -> $(readlink "$dest")"
    options_kind=symlink
  else
    hunks=$(diff -u "$dest" "$src" | grep -c '^@@')
    reason="既存の設定がdotfilesと異なります（${hunks}か所）"
    options_kind=file
  fi
  gap; printf "$I"'%s╭─ ⚠ %s ─────────────────────────────%s\n' "$C_YELLOW" "$title" "$C_RESET"
  printf "$I"'%s│%s  %s~/%s%s\n' "$C_YELLOW" "$C_RESET" "$C_BOLD" "$rel" "$C_RESET"
  printf "$I"'%s│%s  %s\n' "$C_YELLOW" "$C_RESET" "$reason"
  printf "$I"'%s╰────────────────────────────────────%s\n' "$C_YELLOW" "$C_RESET"; gap
  show_diff "$dest" "$src"
  gap

  while :; do
    if [ "$options_kind" = symlink ]; then
      choice=$(ui_choose "どうしますか？" \
        "既存のシンボリックリンクを残す" \
        "dotfilesのコピーで置き換える（リンクはバックアップ）" \
        "ターミナルで差分を表示" \
        "今回はスキップ") || choice="今回はスキップ"
    else
      choice=$(ui_choose "どうしますか？" \
        "既存の設定を残す" \
        "dotfilesで置き換える（バックアップあり）" \
        "1か所ずつ選んで統合する" \
        "ターミナルで差分を表示" \
        "今回はスキップ") || choice="今回はスキップ"
    fi

    case $choice in
      "既存"*)
        ok "~/$rel" "既存の設定を残しました"
        RESULT=kept
        return 0
        ;;
      "dotfiles"*)
        replace_with "$src" "$dest" "$rel" || return 1
        ok "~/$rel" "dotfilesで置き換えました"
        RESULT=replaced
        return 0
        ;;
      "1か所ずつ選んで統合する")
        merge_in_terminal "$src" "$dest" "$rel"
        case $? in
          0) ok "~/$rel" "統合結果を適用しました"; RESULT=merged; return 0 ;;
          1) return 1 ;;
          *) info "  統合をやめました。~/$rel は変更していません。" ;;
        esac
        ;;
      "ターミナルで差分を表示")
        show_diff "$dest" "$src"
        gap
        ;;
      *)
        ok "~/$rel" "スキップしました"
        RESULT=skipped
        return 0
        ;;
    esac
  done
}
