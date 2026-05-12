# 個人用 LLM Wiki

テキスト資料を一次資料として、自分専用の知識ベース（wiki）をAIで育てるためのリポジトリ。
資料中にURLがあれば AI が自動取得して反映する。

## ディレクトリ構成

```
my-wiki/
├── raw/                       # テキスト資料の投入先（不変層）
│                              #   .md / .txt / .html / .pdf など
├── wiki/                      # AIが管理する Markdown 知識ベース（テキストのみ）
├── scripts/
│   ├── ingest-poll.ps1        # raw/ をポーリングして claude -p /ingest を起動
│   └── register-task.ps1      # Windows Task Scheduler 登録
├── .claude/
│   ├── commands/              # スラッシュコマンド定義
│   └── settings.json          # Claude Code の権限設定
├── CLAUDE.md                  # AI向け運用ルール（schema層）
└── README.md                  # このファイル
```

## 使い方（基本ワークフロー）

### 1. テキスト資料を `raw/` に入れる

エクスプローラーで `raw/` にドラッグ&ドロップ。
- 推奨: `.md` / `.txt`
- それ以外: `.html`（クリッピング）、`.pdf` も対応
- 推奨ファイル名: `YYYY-MM-DD_短いスラッグ.md`

### 2. 取り込み（2通り）

**A. 手動**

```powershell
cd C:\my-wiki
claude
```
を起動し、Claude Code のプロンプトで:
```
/ingest
```

**B. 自動（Windows Task Scheduler）**

初回だけ登録:
```powershell
cd C:\my-wiki
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\register-task.ps1
```

デフォルトは 10 分ごと。間隔変更:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\register-task.ps1 -IntervalMinutes 5
```

タスクを手動実行:
```powershell
Start-ScheduledTask -TaskName MyWikiIngestPoll
```

タスク解除:
```powershell
Unregister-ScheduledTask -TaskName MyWikiIngestPoll -Confirm:$false
```

ログは `.ingest.log` に追記される。

### 3. 確認

`wiki/*.md` をエディタや Obsidian で確認。Obsidian で `C:\my-wiki\wiki` を Vault として開くとグラフビュー / バックリンクが使える。

## スラッシュコマンド

| コマンド            | 説明                                                            |
|---------------------|-----------------------------------------------------------------|
| `/ingest`           | `raw/` の未処理ファイルを読み、URLを辿り、`wiki/` に反映        |
| `/ingest <file>`    | 特定のファイルのみ処理                                          |
| `/query <質問>`     | wiki に問い合わせ。任意で回答を wiki に書き戻し                |
| `/lint`             | wiki の品質チェック（孤立、矛盾、重複、dead source、未処理raw） |

## 仕組み

- `raw/`（一次資料）と `wiki/`（整理済み）を分離。
- `raw/` は **不変**。一度入れたら削除も改名もしない（CLAUDE.md ルール）。
- 処理済み判定は wiki ページの `sources:` フロントマターで行う。
- URL が本文中にあれば AI が **WebFetch** で取得して内容を反映、`references:` に記録。
- wiki は **テキストのみ**（画像埋め込みなし）。
- `CLAUDE.md` がAIの振る舞いルール（粒度、命名、リンク方針、URL方針、更新方針）。

## バージョン管理

```powershell
cd C:\my-wiki
git status
git add .
git commit -m "..."
git push
```

`.ingest.log` と `.ingest.lock` は `.gitignore` 済み。

## 参考

- 元アイデア: https://note.com/yasuhitoo/n/naf7246ce43cc
