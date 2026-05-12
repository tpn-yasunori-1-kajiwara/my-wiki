---
description: wiki/ の品質チェック（孤立、矛盾、重複、dead source、未処理raw の検出）
argument-hint: "（引数不要）"
---

# /lint — wikiの品質チェック

`wiki/` 全体と `raw/` をスキャンし、以下の問題を **レポートのみ** 返してください。**自動修正はしない**。

## チェック項目

1. **sources欠落 / 空**
   - フロントマターに `sources:` がない、または空配列のページ（`tags: [meta]` 付きは除外）。

2. **dead source**
   - `sources:` 記載のファイルが `raw/` に存在しないページ。
   - Glob で `raw/*` を取得し突き合わせる。

3. **未処理 raw**
   - `raw/` にあるが、どの wiki ページの `sources:` にも記載がないファイル（処理漏れの可能性）。

4. **孤立ページ**
   - どのページからも `[[このページ名]]` でリンクされていないページ。

5. **title / aliases 重複**
   - 異なるファイル間で同じ title または同じ aliases を持つもの。

6. **同義疑い**
   - ファイル名やtitleが非常に近い複数ページ。

7. **要レビューフラグ**
   - 本文に `> **要レビュー:**` を含むページ。

8. **画像埋め込み（仕様違反）**
   - 本文に `![](...)` を含むページ（テキストのみのルール違反）。

9. **frontmatter 不正**
   - 必須項目 (`title`, `sources`, `created`, `updated`) のいずれかが欠けているページ（meta除く）。

## 出力フォーマット

```
## /lint レポート（YYYY-MM-DD）

### 1. sources欠落 (N件)
- wiki/foo.md

### 2. dead source (N件)
- wiki/baz.md → 参照: 2026-01-01_missing.md（raw/ に存在しない）

### 3. 未処理 raw (N件)
- raw/2026-05-12_unprocessed.md

...
```

問題ゼロなら「✓ 問題なし」と表示してください。
