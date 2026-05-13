---
title: index
aliases: [トップ, 目次]
tags: [meta]
sources: []
created: 2026-05-12
updated: 2026-05-13
---

# index — wiki目次

このページは目次。AI が `/ingest` を実行する際、ここに新規ページの索引を追記してよい。

## カテゴリ別索引

### ナレッジ管理 / LLM Wiki の考え方
- [[LLM Wiki]] — カーパシー由来の個人用ウィキというアプローチそのもの
- [[3層構造]] — raw / wiki / schema の3レイヤー設計
- [[Ingest-Query-Lint]] — AIが担う3つの基本操作
- [[FarzaPedia]] — LLM Wiki の公開実例

### Claude Code / セキュリティ
- [[Claude-Codeのセキュリティ]] — 多層防御のレベル1〜5
- [[プロンプトインジェクション]] — LLM固有の代表的リスク
- [[サンドボックス]] — Seatbelt / bubblewrap / devcontainer による隔離
- [[Claude-Codeのフック]] — PreToolUse / ConfigChange による能動的検査

### AIと産業 / キャリア論
- [[AI企業の受託シフト]] — AIラボが実装支援・受託へ降りてくる動き
- [[AI時代のキャリア戦略]] — 職位より移動可能性、三資本、産業地図のポジション

## 最近の更新

- 2026-05-13: [[Claude-Codeのセキュリティ]], [[サンドボックス]], [[Claude-Codeのフック]], [[3層構造]], [[Ingest-Query-Lint]] にコマンド・設定例を追記（コマンド保存ルールの遡及適用）
- 2026-05-13: [[AI企業の受託シフト]], [[AI時代のキャリア戦略]] を新規作成
- 2026-05-12: [[Claude-Codeのセキュリティ]], [[プロンプトインジェクション]], [[サンドボックス]], [[Claude-Codeのフック]] を新規作成
- 2026-05-12: [[LLM Wiki]], [[3層構造]], [[Ingest-Query-Lint]], [[FarzaPedia]] を新規作成

## メモ

- 本ページは meta タグを持つため /lint の `sources:` 欠落チェックの対象外。
- `raw/` にテキスト資料を投入 → `/ingest` または定期ポーリングが処理。
- 矛盾や重複は `/lint` で検出可能。
