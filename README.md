# 個人用 LLM Wiki

図解（PNG）を一次資料として、自分専用の知識ベース（wiki）をAIで育てるためのリポジトリ。

## ディレクトリ構成

```
my-wiki/
├── raw/                       # PNG図解を投入する場所（不変）
├── wiki/                      # AIが管理する Markdown 知識ベース
├── .claude/
│   ├── commands/              # スラッシュコマンド定義
│   └── settings.json          # Claude Code の権限設定
├── CLAUDE.md                  # AI向け運用ルール（schema層）
└── README.md                  # このファイル
```

## 使い方（基本ワークフロー）

### 1. PNG図解を `raw/` に入れる

エクスプローラーで `raw/` フォルダにPNGをドラッグ&ドロップするだけ。
推奨ファイル名: `YYYY-MM-DD_短い英語スラッグ.png`（例: `2026-05-12_data-pipeline.png`）

### 2. Claude Code をこのフォルダで起動

```powershell
cd C:\product_env\my-wiki
claude
```

### 3. スラッシュコマンドを実行

| コマンド            | 説明                                                            |
|---------------------|-----------------------------------------------------------------|
| `/ingest`           | `raw/` の未処理PNGを読み、`wiki/` に概念ごとに反映              |
| `/ingest <file>`    | 特定のPNGのみ処理                                               |
| `/query <質問>`     | wiki に問い合わせ。任意で回答を wiki に書き戻し                |
| `/lint`             | wiki の品質チェック（孤立、矛盾、重複、dead source 検出）       |

### 4. 結果を確認

`wiki/*.md` をエディタで開いて読む。Obsidian で `my-wiki/wiki` フォルダを Vault として開くと、`[[link]]` がそのまま機能してグラフビューで関連性が見える。

## 仕組み（簡単に）

- `raw/`（一次資料）と `wiki/`（整理済み）を分離。
- `CLAUDE.md` がAIの振る舞いルール（粒度、命名、リンク方針、更新方針）を定義。
- Claude Code は **PNG画像を視覚的に直接読める** ため、画像のままインプットにできる（OCR不要）。
- wiki ページのフロントマター `sources:` に出典PNG名を記録することで、どの図から派生した記述かを追跡。
- これが「処理済み」マーカーも兼ねるので、重複取り込みを防げる。

## 編集環境

- **編集（AI）**: Claude Code（このCLI）。
- **閲覧（任意）**: Obsidian で `wiki/` フォルダを Vault として開くと、グラフビュー / バックリンクが使える。

## バージョン管理

`git init` 済み（ローカルのみ）。

```powershell
git status            # 現在の差分を確認
git add .
git commit -m "..."   # 区切りでコミット
```

## 参考

- 元アイデア: https://note.com/yasuhitoo/n/naf7246ce43cc
- 本リポジトリでは「raw = PNG図解」に特化させてある点が元記事との違い。
