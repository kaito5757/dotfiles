<div align="center">

# 🍵 dotfiles

**まっさらなMacを、1行で「いつもの開発環境」に。**<br>
すでに使っているMacでは、今の設定とぶつかったところだけ、ひとつずつ相談しながら。

![macOS](https://img.shields.io/badge/macOS-Apple_Silicon-1e1e2e?style=flat-square&logo=apple&logoColor=cdd6f4)
![bash](https://img.shields.io/badge/bash-3.2_OK-1e1e2e?style=flat-square&logo=gnubash&logoColor=a6e3a1)
![theme](https://img.shields.io/badge/theme-Catppuccin_Mocha-1e1e2e?style=flat-square&labelColor=1e1e2e&color=cba6f7)
![secrets](https://img.shields.io/badge/secrets-gitleaks_guarded-1e1e2e?style=flat-square&labelColor=1e1e2e&color=f38ba8)

<img src="docs/demo.svg" width="760" alt="setup.sh の実行画面。競合した設定を1か所ずつ選んで統合し、最後に結果をまとめて表示している">

</div>

## ⚡ はじめる

**まっさらなMac** — ターミナルに貼るだけ。git も Homebrew もいりません。

```bash
curl -fsSL https://raw.githubusercontent.com/kaito5757/dotfiles/main/install.sh | bash
```

**いつものMac** — clone して実行。何度実行しても安全です。

```bash
gh repo clone kaito5757/dotfiles ~/dev/personal/kaito5757/dotfiles
```

```bash
cd ~/dev/personal/kaito5757/dotfiles && ./setup.sh
```

> [!TIP]
> 迷ったら Enter。いつも「何も壊さない方」が選ばれます。

## 🧭 setup.sh がやること

どの手順も **まず一覧で見せて、違うところだけ聞く** 。黙って上書きはしません。

| | 手順 | 内容 |
|---|---|---|
| 🍺 | Homebrew | なければ公式インストーラーで入れる。Brewfile の不足分だけ入れる（アップグレードも削除もしない） |
| 📄 | 設定ファイル | dotfiles から**コピー**する。同じなら何もしない、違えば差分を見せて相談 |
| 🧰 | mise | node・python などのツールをまとめて入れる |
| 🍎 | macOS と Loop | キーリピート・トラックパッド・Dock・Caps Lock・Loop のショートカットを揃える |
| 🚀 | アプリの初期設定 | OrbStack を起動、Loop の権限画面を開く、最後に Ghostty へ |

長い処理はスピナーだけ表示して、細かい出力は `~/.local/state/dotfiles/logs/` に残します。最後に「次にやること」（ログアウト、各アプリへのログインなど）をまとめて表示します。

## 🧩 入っているもの

| | |
|---|---|
| **シェル** | zsh · [Starship](https://starship.rs) · fzf · zoxide · autosuggestions · syntax-highlighting |
| **ターミナル** | [Ghostty](https://ghostty.org)（Catppuccin Mocha · JetBrains Mono Nerd Font · カーソルが尾を引くシェーダー） |
| **言語・ツール** | [mise](https://mise.jdx.dev) で node · python · bun · pnpm |
| **CLI** | gh · supabase · gum · gitleaks |
| **アプリ** | Cursor · OrbStack · TablePlus · Loop · Slack · Discord |
| **macOS** | 速いキーリピート · タップでクリック · Dock は右に隠す · Caps Lock → Control |

## 🤝 今の設定とぶつかったら

`ghostty/config` が違っていたら、こんなふうに聞かれます。

```text
◆  どうしますか？
│    1  既存の設定を残す
│    2  dotfilesで置き換える（バックアップあり）
│    3  1か所ずつ選んで統合する
│    4  ターミナルで差分を表示
│    5  今回はスキップ
```

**3** を選ぶと、Gitの競合解消のように違う箇所ごとに「このMac / dotfiles / 両方」を選べます。どの道を選んでも、置き換える前に `~/.local/state/dotfiles/backups/<日時>/` へバックアップします。

## 🔐 秘密は秘密のまま

公開リポジトリなので、トークンやパスワードは三重に守ります。

- **コミット時** — [gitleaks](https://github.com/gitleaks/gitleaks) が検査して、見つけたら止める（`./setup.sh` を一度実行すると有効）
- **push時** — GitHub の push protection が既知のトークンを拒否
- **画面表示** — 差分にトークンらしき値があれば `[伏せ字]` で表示（ファイルの中身はそのまま）

Macごとの秘密は `~/.zshrc.local` など、リポジトリの外に置きましょう（`.gitignore` 済み）。

<details>
<summary><b>🛠 カスタマイズ</b></summary>

### 設定ファイルを増やす

1. ファイルをリポジトリにコピーする（例：`git/.gitconfig`）
2. `setup.sh` の `CONFIGS` に `git/.gitconfig|.gitconfig` を1行足す
3. `./setup.sh` で「最新です」になるのを確かめてからコミット

アプリは `Brewfile`、言語・ツールは `mise/config.toml` に足します。

### macOS の設定を変える

`macos/defaults.txt` を1行1項目で編集します。今の値は `defaults read <domain> <key>`、型は `defaults read-type <domain> <key>` で確認できます。

```text
NSGlobalDomain|KeyRepeat|float|2|キーリピートの速度（小さいほど速い）
```

### Loop の設定を取り込む

Loop の画面で設定を変えたら、次を実行してコミットします（管理している項目だけ取り込みます）。

```bash
./scripts/export-loop.sh
```

### MacBook と Mac Studio で変えたい

コピー方式なので、各Macで直接書き換えてOK。次回の `./setup.sh` では「既存の設定を残す」を選べば残ります。毎回聞かれたくない部分は、別ファイルに分けて読み込みます。

```bash
# ~/.zshrc（dotfiles側）の末尾
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
```

Ghostty なら `config-file = ?local.config`（`?` を付けるとファイルがなくてもエラーにならない）。

</details>

<details>
<summary><b>🛟 困ったとき</b></summary>

### バックアップから戻す

```bash
ls ~/.local/state/dotfiles/backups/
```

```bash
cp -p ~/.local/state/dotfiles/backups/<日時>/.config/ghostty/config ~/.config/ghostty/config
```

シンボリックリンクだったものは `cp` ではなく `mv` で戻します。

### 何が起きたか見たい

細かい出力は `~/.local/state/dotfiles/logs/<日時>.log` にあります。失敗したときは最後の部分が画面にも出ます。

### Caps Lock を元に戻す

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

- **途中でやめたい** — Ctrl-C。置き換えは一時ファイルからの `mv` なので、書きかけのファイルは残りません。
- **シンボリックリンクがあった** — 勝手に上書きしません。置き換えるのはリンク自体だけで、リンク先は触りません。
- **色が邪魔** — `NO_COLOR=1 ./setup.sh`
- **矢印キーで選びたい** — gum（Brewfile に入っています）があれば自動でそうなります。

</details>

<details>
<summary><b>📁 構成</b></summary>

```text
dotfiles/
├── install.sh            # curl | bash 用。一時フォルダに落として setup.sh を実行
├── setup.sh              # 5つの手順の本体
├── Brewfile              # アプリとCLI
├── scripts/
│   ├── install-config.sh # 表示・質問・コピー・統合
│   ├── apply-defaults.sh # macOS と Loop の設定
│   └── export-loop.sh    # Loop の設定を dotfiles に取り込む
├── macos/                # defaults.txt · loop.plist · Caps Lock 用の LaunchAgent
├── zsh/                  # .zprofile · .zshrc
├── ghostty/              # config · shaders/cursor_smear.glsl
├── starship/             # starship.toml
├── mise/                 # config.toml
└── .githooks/pre-commit  # gitleaks
```

</details>

<br>

<div align="center">
<sub>🍵 Made with a cup of tea and slightly too many config files.</sub>
</div>
