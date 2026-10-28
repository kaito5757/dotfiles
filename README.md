# dotfiles

Mac（MacBook Pro / Mac Studio など）の開発環境を再現するためのdotfiles。

設定ファイルは**シンボリックリンクではなくコピー**で配置する。セットアップ後は各Macで自由に変更でき、Mac固有の変更がGit管理対象に混ざらない。既存の設定とdotfilesで内容が異なる場合は、Gitのコンフリクト解消のように対話形式で「残す・置き換える・統合する」を選べる。

## 対応環境

- macOS（Apple Silicon）
- macOS標準の `/bin/bash`（3.2）で動作
- 事前に必要なものはない（Homebrew・git・gumなどは `setup.sh` の中で入る）
- [gum](https://github.com/charmbracelet/gum) はBrewfileに含まれる。Homebrewの手順で入ったあとは矢印キーで選ぶメニューになり、入るまでは番号入力になる

## 管理対象

| 管理ファイル | インストール先 |
|---|---|
| `zsh/.zprofile` | `~/.zprofile`（HomebrewとOrbStackのコマンドを使えるようにする設定） |
| `zsh/.zshrc` | `~/.zshrc` |
| `ghostty/config` | `~/.config/ghostty/config` |
| `ghostty/shaders/cursor_smear.glsl` | `~/.config/ghostty/shaders/cursor_smear.glsl` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `mise/config.toml` | `~/.config/mise/config.toml` |
| `macos/local.dotfiles.capslock-to-control.plist` | `~/Library/LaunchAgents/`（ログイン時に Caps Lock を Control にする） |
| `macos/defaults.txt` | macOS本体の設定（`defaults write` で反映。コピーしない） |
| `macos/loop.plist` | Loopの設定（Loopの設定に取り込む。コピーしない） |
| `Brewfile` | `brew bundle` で使用（コピーしない） |

## 初回セットアップ

### 買ったばかりのMac（何も入っていない）

「ターミナル」アプリ（アプリケーション → ユーティリティ）を開き、次の1行を貼り付けて実行する。`git` もHomebrewも不要。

```bash
curl -fsSL https://raw.githubusercontent.com/kaito5757/dotfiles/main/install.sh | bash
```

- リポジトリを一時フォルダにダウンロードして `setup.sh` を実行する。終わると一時フォルダは削除される。
- 「Homebrewをインストールしますか？」に `y` と答える。Macのパスワードを聞かれる。Xcode Command Line Tools（`git` など）もここで入る。
- 続けて、Brewfileのアプリ（gum・Ghostty・Cursorなど）、設定ファイル、miseのツールの順に入る。
- 最後に、OrbStackの起動、Loopの権限の許可、Ghosttyを開くかを聞かれる。以降はGhosttyで作業する。

あとで設定を編集・コミットする場合は、GitHubにログインしてからcloneし、`./setup.sh` を一度実行する（コミット前の機密情報チェックが有効になる）。

```bash
gh auth login
```

```bash
gh repo clone kaito5757/dotfiles ~/dev/personal/kaito5757/dotfiles
```

### すでに使っているMac

```bash
gh repo clone kaito5757/dotfiles ~/dev/personal/kaito5757/dotfiles
```

```bash
cd ~/dev/personal/kaito5757/dotfiles && ./setup.sh
```

既存の設定と内容が異なるファイルは、競合として1件ずつ選べる（下記）。

## `./setup.sh` の流れ

何度実行しても安全（冪等）。リポジトリの場所はどこでもよい（`setup.sh` の配置場所を基準に動く）。

1. **Homebrew**：`brew bundle check` で不足を確認し、不足がある場合のみ確認後に `brew bundle install --no-upgrade` を実行する。導入済みのものは再インストール・アップグレードしない。`brew bundle cleanup` は実行しない。Homebrewがなければ、確認したうえで公式のインストーラー（<https://brew.sh>）を実行する。断った場合はこの手順を飛ばす。
2. **設定ファイル**：2段階で処理する。
   1. **全体の確認**：全ファイルの状態（`新規配置` / `変更なし` / `競合あり` / `処理不可`）を一覧で表示する。この段階では何も変更しない。
   2. **適用**：各ファイルを次のように処理する。
      - インストール先にファイルがない → コピー（`新しく配置しました`）
      - 内容が同じ → 何もしない（`最新です`）
      - 内容が異なる → 差分を表示し、対話で選択（下記）
3. **mise**：`~/.config/mise/config.toml` が存在する場合のみ、確認後に `mise install` を実行する。手順2で既存の設定を残した場合は、残した設定でインストールされる。
4. **macOSとLoopの設定**：`macos/defaults.txt` と `macos/loop.plist` を、このMacの今の設定と比べて一覧にする（この段階では何も変更しない）。違う項目があれば「1つずつ選ぶ / すべてdotfilesに合わせる / 何も変えない」から選ぶ。詳しくは「macOSとLoopの設定」を参照。
5. **アプリの初期設定**：アプリごとに、コマンドでできることはコマンドで行う。どれも確認してから実行する。
   - OrbStack：`orb start` で起動する（アプリの画面は開かない）。起動すると `docker`・`kubectl` などのコマンドが使えるようになる。初回は管理者パスワードを聞かれることがある。すでに起動していれば何もしない
   - Loop：起動して、システム設定のアクセシビリティの画面を開く。一覧の「Loop」をオンにする（macOSの仕様で、この許可だけは手動）
   - ログインが必要なものを案内する：Cursor・Slack・Discord（アプリでログイン）、`gh auth login`（未ログインの場合のみ）、`supabase login`
   - 最後にGhosttyを開くか確認する。開くと、新しい設定（テーマ・フォント・starshipのプロンプト）で使える。Ghosttyの中で実行している場合は、新しいウィンドウを開くよう案内だけ出す

最後に、結果を枠で表示する。各ファイルの結果、バックアップとログの場所、「次にやること」（ログアウト、各アプリへのログインなど）をまとめて確認できる。失敗した処理があれば終了コード1で終わるため、原因を直してから再実行する。

### 画面の表示

- 左端の縦の線（`│`）で手順全体をつなぎ、答えた質問は「◇ 質問」と答えの2行に畳む。
- `brew bundle install`・`mise install`・`orb start` の細かい出力は隠し、スピナーと経過秒数だけを表示する。出力の全体は `~/.local/state/dotfiles/logs/<日時>.log` に残す。失敗したときは、ログの最後の部分を表示する。
- 色はGhostty・Starshipと同じCatppuccin Mocha。24ビットカラーに対応した端末（Ghosttyなど）ではそのままの色、対応していない端末（macOS標準のターミナルなど）では近い色で表示する。
- 環境変数 `NO_COLOR` を設定すると色を付けない。gumが入っていれば、メニューは矢印キーで選べる形になる。

## macOSとLoopの設定

### 管理している項目

`macos/defaults.txt` に1行1項目で書いている（値は、このファイルを作ったMacの設定）。

| 分類 | 項目 |
|---|---|
| キーボード | キーリピートの速度、リピート開始までの時間 |
| 文字入力 | 文頭の自動大文字、スペース2回でピリオド |
| トラックパッド | 移動速度、タップでクリック、2本指で右クリック、3本指ドラッグ（内蔵と外付けの両方） |
| Dock | 自動で隠す、位置、ホットコーナー右下 |
| Loop | 起動キー、ショートカット一式、ログイン時の自動起動、見た目（`macos/loop.plist`） |
| Caps Lock | Controlとして動かす（すべてのキーボード。`hidutil` をログイン時に実行） |

Dockのアプリの並びと入力ソースは、Macごとに違うことが多いので管理しない。

### 反映のしかた

- 違う項目だけを一覧にし、「このMacのまま / dotfilesに合わせる」を選ぶ。黙って上書きはしない。
- Dockの設定を変えた場合は、Dockを再起動して反映する。
- キーボード・文字入力・トラックパッドの設定は、ログアウトして入り直すと反映される。
- Loopの設定を変える場合は、Loopを一度終了してから取り込み、起動し直す。使用回数など、管理していない項目はそのまま残る。
- Caps Lock の設定ファイルは、ほかの設定ファイルと同じように配置し（競合時の選択も同じ）、その場で読み込む。

### 値を変えたいとき

- macOSの設定：`macos/defaults.txt` の値を書き換えてコミットする。項目を増やす場合は、`defaults read <domain> <key>` で今の値を、`defaults read-type <domain> <key>` で型を確かめてから1行足す。
- Loopの設定：Loopの画面で設定を変えたあと、次を実行してからコミットする（管理している項目だけを取り込む）。

  ```bash
  ./scripts/export-loop.sh
  ```

### Caps Lock の設定を元に戻す

```bash
launchctl bootout gui/$(id -u)/local.dotfiles.capslock-to-control
```

```bash
rm ~/Library/LaunchAgents/local.dotfiles.capslock-to-control.plist
```

```bash
hidutil property --set '{"UserKeyMapping":[]}'
```

## 競合時の選択肢

競合が見つかると、まず既存の設定とdotfilesの差分を表示してから、メニューを出す。差分は、行の左に「どちらにある行か」を表示する。`このMac`（赤の背景）は今の設定にだけある行、`dotfiles`（緑の背景）はリポジトリの設定にだけある行、ラベルなし（薄い色）は共通の行。行頭に `-` や `+` の印は付けないので、表示されている本文は設定に書かれている内容そのまま。空行の差分は「（空行）」と表示する。変更のあった行番号を「◯行目」として示す。差分が長いときはページャー（`less`）で開くので、`q` で閉じるとメニューに進む。

```text
│  ╭─ ⚠ 競合 1/2 ─────────────────────────────
│  │  ~/.config/starship.toml
│  │  既存の設定がdotfilesと異なります（2か所）
│  ╰────────────────────────────────────
│
│  ■ このMac（今の設定）   ■ dotfiles（リポジトリの設定）   色なし: 共通の行
│
│  ── 56行目 ──
│           │ [git_status]
│           │ style = "bold yellow"
│  このMac  │ format = " [$all_status$ahead_behind]($style) "
│  dotfiles │ format = "  [$all_status$ahead_behind]($style)"
│
◆  どうしますか？
│    1  既存の設定を残す
│    2  dotfilesで置き換える（バックアップあり）
│    3  1か所ずつ選んで統合する
│    4  ターミナルで差分を表示
│    5  今回はスキップ
│  › 番号を押す [1-5]（Enterで1）:
```

答えると、メニューは次のように1行に畳まれる。

```text
◇  どうしますか？
│  1か所ずつ選んで統合する
```

| 選択肢 | 動作 |
|---|---|
| 既存の設定を残す | 既存ファイルをそのまま残す |
| dotfilesで置き換える | 既存ファイルをバックアップしてから、dotfilesの内容で置き換える |
| 1か所ずつ選んで統合する | 違っている箇所ごとにどちらを使うか選び、確認後に適用する（下記） |
| ターミナルで差分を表示 | 差分をもう一度表示し、メニューに戻る |
| 今回はスキップ | 今回は何もしない（次回の実行で再び確認される） |

番号のキーを押した時点で決まる（Enterは不要）。Enterだけを押すと安全側の選択になる（メニューでは1番、確認では「いいえ」）。Ctrl-Dは「やめる」として扱う（メニューでは「今回はスキップ」、確認では「いいえ」）。Ctrl-Cで中断しても、一時ファイルを削除して終了する。ファイルの置き換えは一時ファイルからの `mv` で行うため、書きかけの状態のファイルは残らない。

### 1か所ずつ選んで統合する

ターミナルの中だけで完結する（追加のツールは不要）。Gitの競合解消と同じように、違っている箇所ごとにどちらを使うかを選ぶ。

```text
  ── 統合 2/2 か所目（56行目）──
  このMac  │ format = " [$all_status$ahead_behind]($style) "
  dotfiles │ format = "  [$all_status$ahead_behind]($style)"

  この部分はどちらにしますか？

    1  このMacの内容を使う
    2  dotfilesの内容を使う
    3  両方残す（このMac → dotfiles の順）
```

| 箇所の種類 | 選択肢 |
|---|---|
| 両方にあって内容が違う | このMacの内容 / dotfilesの内容 / 両方残す |
| dotfilesにだけある行 | 追加しない / 追加する |
| このMacにだけある行 | 残す / 削除する |

すべて選ぶと「今の設定 → 統合結果」の差分が表示されるので、次から選ぶ。

- `適用する`：バックアップしてから適用する
- `選び直す`：最初の箇所から選び直す
- `統合をやめる`：何も変更せず、競合のメニューに戻る

すべて「このMac」を選んだ場合は変更がないので、そのままメニューに戻る。箇所の中の一部だけを変えたい場合は、近い方を選んで適用したあと、エディタで直接直す。リポジトリ内のファイルを書き換えることはない。

### シンボリックリンクがある場合

既存のシンボリックリンクは自動では上書きしない。

- リンク先の内容がdotfilesと同じ → そのまま残す
- 内容が異なる、またはリンク切れ → 「既存のシンボリックリンクを残す」「dotfilesのコピーで置き換える」「ターミナルで差分を表示」「今回はスキップ」から選ぶ。置き換えるのはリンク自体だけで、リンク先のファイルは変更しない。リンク先経由で書き換えてしまうのを防ぐため、統合はできない。

インストール先がディレクトリ、またはディレクトリへのリンクの場合や、読み書きの権限がない場合は、何も変更せずエラーとして報告する。

## バックアップと復元

置き換え（「dotfilesで置き換える」「統合結果を適用する」）をした場合のみ、置き換え前のファイルを1回の実行ごとに次の場所へ保存する。

```text
~/.local/state/dotfiles/backups/<YYYYMMDD-HHMMSS>/<ホームからの相対パス>
# 例: ~/.local/state/dotfiles/backups/20261028-210000/.config/ghostty/config
```

- `$XDG_STATE_HOME` が設定されていれば、それを基準にする
- 実行のたびに新しいフォルダを作り、以前のバックアップは上書き・削除しない
- シンボリックリンクはリンクのまま保存する
- 不要になったバックアップは手動で削除する

復元方法：

```bash
ls ~/.local/state/dotfiles/backups/
```

```bash
cp -p ~/.local/state/dotfiles/backups/20261028-210000/.config/ghostty/config ~/.config/ghostty/config
```

シンボリックリンクを復元する場合は、`cp` ではなく `mv` を使う（`cp` だとリンク先の内容がコピーされるため）。

```bash
mv ~/.local/state/dotfiles/backups/20261028-210000/.zshrc ~/.zshrc
```

## 機密情報の対策

このリポジトリは公開するため、トークンやパスワードがコミットされないように二重で防ぐ。

1. **コミット時（手元）**：`.githooks/pre-commit` が [gitleaks](https://github.com/gitleaks/gitleaks) でステージした内容を検査し、見つかればコミットを中止する。gitleaksが入っていない場合もコミットを中止する。
   - `./setup.sh` を実行すると有効になる（`git config core.hooksPath .githooks`）。cloneしたら一度実行する。
   - gitleaksはBrewfileに含まれる。
2. **push時（GitHub）**：GitHubのpush protectionが、既知の形式のトークンを含むpushを拒否する。個人アカウントで新しく作った公開リポジトリでは既定で有効になる。リポジトリの Settings → Advanced Security（Code security）で、Secret Protection と Push protection が有効か確認する。

あわせて、`.gitignore` で `.env`・`*.local`・鍵ファイルなどをGitの管理対象外にしている。Macごとの秘密の設定は `~/.zshrc.local` のように、リポジトリの外のファイルに書く。

`git commit --no-verify` を使うとコミット時のチェックを飛ばせてしまうので、使わない。

### 画面に表示するときの伏せ字

`setup.sh` が差分や統合の箇所を表示するときは、機密情報らしき値を `[伏せ字]` に置き換えて表示する（画面への表示だけで、ファイルの内容は変えない）。

- 名前に `TOKEN`・`SECRET`・`PASSWORD`・`API_KEY`・`ACCESS_KEY`・`PRIVATE_KEY`・`CREDENTIAL`・`AUTH` を含む設定の値（例：`export GITHUB_TOKEN="[伏せ字]"`）
- GitHub（`ghp_` など）・OpenAI / Anthropic（`sk-`）・Slack（`xox?-`）・AWS（`AKIA`）・Google（`AIza`）のトークン、JWT
- 秘密鍵（`BEGIN ... PRIVATE KEY` から `END` まで）

形式が決まっていない値は見逃すことがあるので、機密情報はそもそも `~/.zshrc.local` などリポジトリの外のファイルに書く。

## 新しい設定をdotfilesへ追加する

1. 設定ファイルをリポジトリにコピーする（例：`mkdir -p git && cp ~/.gitconfig git/.gitconfig`）。
2. `setup.sh` の `CONFIGS` に1行追加する（`dotfiles内のパス|ホームからの相対パス`）。

   ```text
   git/.gitconfig|.gitconfig
   ```

3. `./setup.sh` を実行し、`最新です` と表示されることを確認してからコミットする。

アプリを追加する場合は `Brewfile` に追記する。各Macで設定を変更した内容を共通設定に入れたい場合は、手動でリポジトリにコピーしてコミットする（自動では同期しない）。

## MacBookとMac Studioで設定を変える

各Macでの変更はGitに戻らないため、Mac固有の設定はコピー後の各ファイルで直接変更すればよい。再実行すると競合として表示されるので、「既存の設定を残す」か「今回はスキップ」を選ぶ。

再実行のたびに競合が表示されないようにしたい場合は、共通部分だけをdotfilesで管理し、Mac固有の部分を管理対象外のファイルに分けて読み込む。

```bash
# ~/.zshrc の末尾（dotfiles側に書いておく）
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

Ghosttyの場合は `config-file = ?local.config` のように任意の追加ファイルを読み込める（`?` を付けるとファイルがなくてもエラーにならない）。
