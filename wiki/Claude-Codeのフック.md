---
title: Claude Codeのフック
aliases: [Claude Code hooks, PreToolUse, ConfigChange, フック]
tags: [claude-code, security, automation]
sources:
  - "無題1_20260512_192005.txt"
references:
  - "https://zenn.dev/solvio/articles/27c06e4802aa45"
created: 2026-05-12
updated: 2026-05-13
---

# Claude Codeのフック

## 概要
Claude Code が特定のイベント時に自動実行するシェルコマンドの仕組み。[[Claude-Codeのセキュリティ]] レベル4の中核で、権限プロンプトより前に検査を差し込んだり、設定変更を監査ログに残すことができる。

## 本文

### PreToolUse フック
- ツール呼び出しが発生したとき、**権限プロンプトの前に** 実行される。
- 公式ドキュメントの記述: "ツール呼び出しを行うと、PreToolUse フックは権限プロンプトの前に実行"。
- 用途例:
  - 危険コマンド（`rm -rf` 等）を強制的にブロックする。
  - 引数を検査して機密ファイル名が含まれていれば拒否する。
  - 監査ログに残す。

### ConfigChange フック
- 設定（settings.json 等）が変更されたタイミングで実行される。
- 用途: 設定変更の監査ログ記録。誰がいつどの権限を緩めたかを残す。

### 設計上の位置づけ
- 権限設定（allow/deny）と[[サンドボックス]]に加える、もう一段の「能動的な検査」レイヤー。
- フックは utilities ではなく **セキュリティ境界の一部** として設計するのが原典の立場。
- 自動承認モードを使う場合でも、PreToolUse で危険操作だけは止められる。

### 関連する設定上の注意
- 禁止ルール（deny）が未設定だと、確認待機（ask）に分類しても結局実行されてしまう不安定さがある。
- フックだけに頼らず、deny リスト＋サンドボックス＋フックの組み合わせで多層防御する。

## 実装例（原典より）

### PreToolUse フック本体

`.claude/hooks/validate-command.sh` に置く想定。`exit 0` で許可、`exit 2` でブロック。

```bash
#!/bin/bash
# ツール実行前に呼ばれるフック
# exit 0 で許可、exit 2 でブロック

COMMAND="$1"

# 独自のブラックリストを設定
if [[ "$COMMAND" == *"rm -rf"* ]]; then
  echo "rm -rf は禁止されています" >&2
  exit 2
fi

# ドメイン検証（GitHub / npm 以外の curl を拒否する例）
if [[ "$COMMAND" == *"curl"* ]] && [[ "$COMMAND" != *"github.com"* ]] && [[ "$COMMAND" != *"npmjs.org"* ]]; then
  echo "許可されていないドメインへの curl" >&2
  exit 2
fi

exit 0
```

### settings.json への登録

`.claude/settings.json` に matcher 付きで登録する。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": ".claude/hooks/validate-command.sh"
      }
    ]
  }
}
```

### ConfigChange フックの登録

設定変更の監査ログ用。スクリプト本体（例: `.claude/hooks/log-config-change.sh`）は別途用意する。

```json
{
  "hooks": {
    "ConfigChange": [
      {
        "command": ".claude/hooks/log-config-change.sh"
      }
    ]
  }
}
```

## 関連
- [[Claude-Codeのセキュリティ]]
- [[サンドボックス]]
- [[プロンプトインジェクション]]
