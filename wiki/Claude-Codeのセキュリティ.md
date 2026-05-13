---
title: Claude Codeのセキュリティ
aliases: [Claude Code セキュリティ, Claude Codeを安全に使う, Claude Codeセキュリティ設定]
tags: [claude-code, security]
sources:
  - "無題1_20260512_192005.txt"
references:
  - "https://zenn.dev/solvio/articles/27c06e4802aa45"
created: 2026-05-12
updated: 2026-05-13
---

# Claude Codeのセキュリティ

## 概要
Claude Code を「Yesを連打するのが少し怖い」状態で使い続けないための、Anthropic公式ドキュメントに基づく多層防御の設定方法。Solvio株式会社の okawa2929 氏が2026年4月23日にZennで公開したガイドが出典。非エンジニアを含む利用者を想定し、段階的に強化していくレベル1〜5の構成になっている。

## 本文

### 想定する主なリスク
- **[[プロンプトインジェクション]]**: 攻撃者がツール出力やファイル内容に悪意ある指示を仕込み、AIアシスタントの本来の指示を上書きさせる手法。
- **悪意あるライブラリ（サプライチェーン攻撃）**: 例として、週1億ダウンロード規模の `axios` が2026年3月に侵害された事例が紹介されている。
- **ソーシャルエンジニアリング**: 利用者自身の誤認識で危険な指示を実行してしまうケース。

### 防御の基本方針
公式ドキュメントは「権限とサンドボックスは補完的なセキュリティレイヤー」として両立を推奨。**ツールがいずれかのレベルで拒否されていれば、他のレベルはそれを許可できない**という階層構造を取る。

### レベル別の設定（要点）

#### レベル1: 基本設定
- ホームフォルダでの起動禁止。
- 危険コマンドの禁止リスト化。
- 機密ファイル（鍵・トークン等）へのアクセス禁止。
- 外部ダウンロード系コマンドの封鎖。
- 間接実行コマンドの遮断。

> **要レビュー:** `Read` 権限の禁止だけでは Bash 経由の `cat` で機密ファイルが読み出される可能性がある、と原典は警告している。Read 拒否＋Bash 側での deny の両方が必要。

#### レベル2: [[サンドボックス]]化
- macOS の `Seatbelt`、Linux の `bubblewrap` を活用。
- ファイルシステム制限（`denyRead` / `allowRead` / `allowWrite`）。
- ネットワーク通信の許可ドメインリスト化（`WebFetch(domain:)` 等の指定が正解）。

#### レベル3: 自動承認モードの抑制
- `bypassPermissionsMode` は仮想環境内など隔離された場所でしか使わない（無効化が原則）。
- `autoMode` は検証プレビュー段階では無効化。
- 重要操作は `ask`（確認待機）に分類する。

#### レベル4: 高度な制御
- **[[Claude-Codeのフック]]**: `PreToolUse` で権限プロンプト前に介入、`ConfigChange` で設定変更を監査ログ化。
- **CLAUDE.md**: プロジェクト固有のルールを日本語で書き、運用ルールでも縛る（[[3層構造]] の schema 層に相当）。

#### レベル5: 組織展開
- MDM 経由で管理設定を強制配布。
- `devcontainer` で完全隔離環境を作る。
- シークレット管理は 1Password CLI / Doppler / AWS Secrets Manager 等を併用。

### 推奨する実装範囲
- 個人利用: レベル1〜3 を中心に。
- 業務利用: 加えてレベル4〜5 を実装。

## 設定例（原典より）

設定は `~/.claude/settings.json`（ユーザー設定）または `.claude/settings.json`（プロジェクト設定）に書く。サンドボックス側の詳細は [[サンドボックス]]、フック側は [[Claude-Codeのフック]] にも切り出している。

### 起動位置（レベル1）

ホーム直下で起動すると、`~/.ssh` や `~/.aws` まで全部スコープに入る。プロジェクト配下で起動する。

```bash
# 避けるべき
cd ~
claude

# 推奨
cd ~/projects/my-app
claude
```

### 危険コマンドの deny（レベル1）

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(rm -rf /)",
      "Bash(sudo *)",
      "Bash(chmod *)",
      "Bash(chown *)",
      "Bash(dd *)",
      "Bash(mkfs *)"
    ]
  }
}
```

### 機密ファイル deny（レベル1）

Read だけ拒否しても Bash 経由の `cat` で抜けられるので両側を塞ぐ。

```json
{
  "permissions": {
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)",
      "Read(~/.config/**)",
      "Edit(./.env)",
      "Edit(./.env.*)",
      "Edit(~/.ssh/**)",
      "Edit(~/.aws/**)",
      "Bash(cat .env*)",
      "Bash(cat ~/.ssh/*)",
      "Bash(cat ~/.aws/*)"
    ]
  }
}
```

### 外部ダウンロード/間接実行の遮断（レベル1）

```json
{
  "permissions": {
    "deny": [
      "Bash(curl *)",
      "Bash(wget *)",
      "Bash(nc *)",
      "Bash(ncat *)",
      "Bash(telnet *)",
      "Bash(bash -c *)",
      "Bash(sh -c *)",
      "Bash(zsh -c *)",
      "Bash(python -c *)",
      "Bash(python3 -c *)",
      "Bash(node -e *)",
      "Bash(eval *)"
    ]
  }
}
```

### バイパス/自動承認の停止（レベル3）

```json
{
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "disableAutoMode": "disable"
  }
}
```

### 毎回確認（ask）に分類するコマンド（レベル3）

```json
{
  "permissions": {
    "ask": [
      "Bash(git push *)",
      "Bash(git push -f *)",
      "Bash(git reset --hard *)",
      "Bash(mv *)",
      "Bash(npm publish *)",
      "Bash(docker *)"
    ]
  }
}
```

### CLAUDE.md（プロジェクトルール）の最小例（レベル4）

```markdown
# このプロジェクトのセキュリティルール

以下を厳守してください。

## 絶対禁止
- `rm -rf` の使用
- `sudo` の使用
- `.env` `~/.ssh/` `~/.aws/` の読み取り
- 許可されていないドメインへの curl / wget

## 実行前に必ず確認
- `git push`（特に `-f` 付き）
- `npm publish`
- `docker` 系コマンド

## ユーザーへの説明義務
- ツールを実行する前に、日本語でなぜ必要かを説明してください
- 「Yes を押す前にユーザーが理解できる」ことを最優先してください
```

### 組織配布（MDM）用の管理設定（レベル5）

`allowManaged*Only` を true にすると、ローカル設定で緩和できなくなる。

```json
{
  "allowManagedPermissionRulesOnly": true,
  "allowManagedMcpServersOnly": true,
  "allowManagedHooksOnly": true,
  "sandbox": {
    "network": {
      "allowManagedDomainsOnly": true
    }
  },
  "disableBypassPermissionsMode": "disable"
}
```

### セッション中のスラッシュコマンド

```
/permissions   # 現在の権限を確認
/sandbox       # サンドボックスを有効化（環境依存）
```

### 統合設定ファイル例（原典の集約版）

```json
{
  "permissions": {
    "disableBypassPermissionsMode": "disable",
    "disableAutoMode": "disable",
    "deny": [
      "Bash(rm -rf *)",
      "Bash(rm -rf /)",
      "Bash(sudo *)",
      "Bash(chmod *)",
      "Bash(chown *)",
      "Bash(dd *)",
      "Bash(mkfs *)",
      "Bash(curl *)",
      "Bash(wget *)",
      "Bash(nc *)",
      "Bash(telnet *)",
      "Bash(bash -c *)",
      "Bash(sh -c *)",
      "Bash(zsh -c *)",
      "Bash(python -c *)",
      "Bash(python3 -c *)",
      "Bash(node -e *)",
      "Bash(eval *)",
      "Bash(cat .env*)",
      "Bash(cat ~/.ssh/*)",
      "Bash(cat ~/.aws/*)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(~/.ssh/**)",
      "Read(~/.aws/**)",
      "Read(~/.config/**)",
      "Edit(./.env)",
      "Edit(./.env.*)",
      "Edit(~/.ssh/**)",
      "Edit(~/.aws/**)"
    ],
    "ask": [
      "Bash(git push *)",
      "Bash(git reset --hard *)",
      "Bash(mv *)",
      "Bash(npm publish *)",
      "Bash(docker *)"
    ],
    "allow": [
      "Bash(npm run *)",
      "Bash(git status)",
      "Bash(git diff *)",
      "Bash(git log *)",
      "Bash(ls *)",
      "WebFetch(domain:github.com)",
      "WebFetch(domain:docs.anthropic.com)",
      "WebFetch(domain:code.claude.com)"
    ]
  },
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "failIfUnavailable": true,
    "filesystem": {
      "denyRead": ["~/"],
      "allowRead": ["."],
      "allowWrite": []
    },
    "network": {
      "allowedDomains": [
        "github.com",
        "api.github.com",
        "registry.npmjs.org",
        "pypi.org",
        "docs.anthropic.com",
        "code.claude.com"
      ]
    }
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "command": ".claude/hooks/validate-command.sh"
      }
    ],
    "ConfigChange": [
      {
        "command": ".claude/hooks/log-config-change.sh"
      }
    ]
  }
}
```

## 関連
- [[プロンプトインジェクション]]
- [[サンドボックス]]
- [[Claude-Codeのフック]]
- [[3層構造]]
