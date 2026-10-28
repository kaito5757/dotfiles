<div align="center">

<img src="docs/header.svg" width="100%" alt="kaito5757/dotfiles — 夜の机に置かれた小さなMacと、湯気の立つお茶のドット絵">

<br>
<br>

**どのMacを開いても、いつもの開発環境が待っているように。**

<sub>kaito5757 の開発環境を、コマンド1行で再現します。<br>新しいMacにはひと通り揃え、使い込んだMacでは違うところだけを確認しながら反映します。</sub>

<br>
<br>

![macOS](https://img.shields.io/badge/macOS-Apple_Silicon-1e1e2e?style=flat-square&logo=apple&logoColor=cdd6f4)
![bash](https://img.shields.io/badge/bash-3.2-1e1e2e?style=flat-square&logo=gnubash&logoColor=a6e3a1)
![theme](https://img.shields.io/badge/theme-Catppuccin_Mocha-1e1e2e?style=flat-square&labelColor=1e1e2e&color=cba6f7)
![secrets](https://img.shields.io/badge/secrets-gitleaks-1e1e2e?style=flat-square&labelColor=1e1e2e&color=f38ba8)

<br>
<br>

<img src="docs/demo.svg" width="760" alt="setup.sh の実行画面。競合した設定を1か所ずつ選んで統合し、最後に結果をまとめて表示している">

</div>

<br>

## 01 · はじめる

ターミナルで次のコマンドを実行します。新しいMacでも、使い込んだMacでも同じコマンドです。git や Homebrew が入っていなくても実行できます。

```bash
curl -fsSL https://raw.githubusercontent.com/kaito5757/dotfiles/main/install.sh | bash
```

dotfiles 自体を編集する場合は、リポジトリを clone してから実行します。何度実行しても、結果は変わりません。

```bash
gh repo clone kaito5757/dotfiles ~/dev/personal/kaito5757/dotfiles
```

```bash
cd ~/dev/personal/kaito5757/dotfiles && ./setup.sh
```

> [!NOTE]
> 迷ったら Enter を押してください。基本的に、今の設定を変えない選択肢が選ばれます。

## 02 · セットアップの流れ

どの手順でも、まず全体を一覧で表示し、違いがある項目だけを確認します。確認なしに上書きすることはありません。

| | 手順 | 内容 |
|:-:|---|---|
| `1` | Homebrew | 未導入なら公式インストーラーで導入し、Brewfile の不足分だけをインストールする |
| `2` | 設定ファイル | dotfiles からコピーする。内容が同じなら何もせず、違う場合は差分を表示して確認する |
| `3` | mise | node や python などのツールをインストールする |
| `4` | macOS と Loop | キーリピート、トラックパッド、Dock、Caps Lock、Loop のショートカットを揃える |
| `5` | アプリ | OrbStack を起動し、Loop の権限設定画面を開き、最後に Ghostty を開く |

時間のかかる処理はスピナーだけを表示し、詳細な出力は `~/.local/state/dotfiles/logs/` に保存します。最後に、残りの作業（ログアウトや各アプリへのログインなど）をまとめて表示します。

## 03 · 導入されるもの

| | |
|---|---|
| シェル | zsh · [Starship](https://starship.rs) · fzf · zoxide · autosuggestions · syntax-highlighting |
| ターミナル | [Ghostty](https://ghostty.org)（Catppuccin Mocha · JetBrains Mono Nerd Font · カーソルの残像シェーダー） |
| 言語・ツール | [mise](https://mise.jdx.dev) で node · python · bun · pnpm |
| CLI | gh · supabase · gum · gitleaks |
| アプリ | Cursor · OrbStack · TablePlus · Loop · Slack · Discord |
| macOS | 速めのキーリピート · タップでクリック · 右側に自動で隠れる Dock · Caps Lock を Control に変更 |

## 04 · 既存の設定と違うとき

使い込んだMacの設定には、そのMacで積み重ねてきた調整が残っています。dotfiles と違う設定が見つかると、次のように確認します。

```text
◆  どうしますか？
│    1  既存の設定を残す
│    2  dotfilesで置き換える（バックアップあり）
│    3  1か所ずつ選んで統合する
│    4  ターミナルで差分を表示
│    5  今回はスキップ
```

`3` を選ぶと、Git のコンフリクト解消と同じ要領で、違う箇所ごとに「このMac」「dotfiles」「両方」から選べます。置き換える前には、必ず `~/.local/state/dotfiles/backups/<日時>/` にバックアップを保存します。

## 05 · 機密情報の保護

公開リポジトリのため、トークンやパスワードは次の3つの段階で保護しています。

- **コミット時** — [gitleaks](https://github.com/gitleaks/gitleaks) が内容を検査し、機密情報が見つかればコミットを中止します（clone 後に一度 `./setup.sh` を実行すると有効になります）。
- **push 時** — GitHub の push protection が、既知の形式のトークンを含む push を拒否します。
- **画面表示時** — 差分にトークンらしき値があれば、`[伏せ字]` に置き換えて表示します（ファイルの内容は変更しません）。

Mac固有の機密情報は、`~/.zshrc.local` など、リポジトリの外のファイルに書いてください。

<br>

<details>
<summary><b>06 · カスタマイズ</b></summary>

### 設定ファイルを追加する

1. ファイルをリポジトリに置きます（例：`git/.gitconfig`）。
2. `setup.sh` の `CONFIGS` に `git/.gitconfig|.gitconfig` を1行追加します。
3. `./setup.sh` を実行して「最新です」と表示されることを確認してから、コミットします。

アプリは `Brewfile` に、言語・ツールは `mise/config.toml` に追加します。

### macOS の設定を変更する

`macos/defaults.txt` を編集します（1行に1項目）。現在の値は `defaults read <domain> <key>`、型は `defaults read-type <domain> <key>` で確認できます。

```text
NSGlobalDomain|KeyRepeat|float|2|キーリピートの速度（小さいほど速い）
```

### Loop の設定を取り込む

Loop の設定画面で変更したら、次のコマンドを実行してからコミットします。管理対象の項目だけを取り込みます。

```bash
./scripts/export-loop.sh
```

### MacBook と Mac Studio で設定を分ける

設定ファイルはコピーで配置しているため、各Macで直接編集して問題ありません。次回 `./setup.sh` を実行したときに「既存の設定を残す」を選べば、編集した内容はそのまま残ります。毎回確認されたくない部分は、別のファイルに分けて読み込みます。

```bash
# ~/.zshrc（dotfiles 側）の末尾
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

Ghostty の場合は `config-file = ?local.config` と書きます（先頭に `?` を付けると、ファイルがなくてもエラーになりません）。

</details>

<details>
<summary><b>07 · トラブルシューティング</b></summary>

### バックアップから復元する

```bash
ls ~/.local/state/dotfiles/backups/
```

```bash
cp -p ~/.local/state/dotfiles/backups/<日時>/.config/ghostty/config ~/.config/ghostty/config
```

シンボリックリンクを復元する場合は、`cp` ではなく `mv` を使います。

### ログを確認する

詳細な出力は `~/.local/state/dotfiles/logs/<日時>.log` に保存されます。失敗した場合は、ログの末尾が画面にも表示されます。

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

### その他

- **途中でやめたい** — Ctrl-C で中断できます。ファイルの置き換えは一時ファイルからの `mv` で行うため、書きかけのファイルは残りません。
- **シンボリックリンクがある** — 確認なしに上書きはしません。置き換える場合も、対象はリンク自体だけです。リンク先のファイルは変更しません。
- **色を表示したくない** — `NO_COLOR=1 ./setup.sh` で実行します。
- **矢印キーで選びたい** — gum（Brewfile に含まれています）がインストールされていれば、自動で矢印キーのメニューになります。

</details>

<details>
<summary><b>08 · ディレクトリ構成</b></summary>

```text
dotfiles/
├── install.sh            # curl | bash 用。一時フォルダにダウンロードして setup.sh を実行
├── setup.sh              # 5つの手順の本体
├── Brewfile              # アプリと CLI
├── scripts/
│   ├── install-config.sh # 表示・確認・コピー・統合
│   ├── apply-defaults.sh # macOS と Loop の設定
│   └── export-loop.sh    # Loop の設定を dotfiles に取り込む
├── macos/                # defaults.txt · loop.plist · Caps Lock 用の LaunchAgent
├── zsh/                  # .zprofile · .zshrc
├── ghostty/              # config · shaders/cursor_smear.glsl
├── starship/             # starship.toml
├── mise/                 # config.toml
├── docs/                 # README 用の画像
└── .githooks/pre-commit  # gitleaks
```

</details>

<br>

<div align="center">
<img src="docs/footer.svg" width="100%" alt="">
<br>
<sub>kaito5757 · since 2026</sub>
</div>
