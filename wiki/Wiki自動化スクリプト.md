---
title: Wiki自動化スクリプト
aliases: [wiki-daemon, MyWikiDaemon, 自動化フロー, send-to-wiki]
tags: [automation, scripts, setup]
sources:
  - "個人wikiシステムの使い方.txt"
  - "2026-05-13_124645_README.md"
created: 2026-05-13
updated: 2026-05-13
---

# Wiki自動化スクリプト

## 概要
本リポジトリの `scripts/` 配下に置かれた、raw/ への投入と `/ingest` 起動を自動化する仕組み一式。デーモン（HTTP受け口 + FileSystemWatcher）、Explorer「送る」、Chrome 拡張の 3 経路を統合する。これらが揃うことで、[[Ingest-Query-Lint]] の Ingest を手動で起動する手間がほぼゼロになる。

詳細なセットアップ手順・トラブルシューティングは `README.md` を参照。

## 本文

### 構成ファイル

```
scripts/
  wiki-daemon.ps1            # 常駐デーモン (HTTP 7777 + raw/監視 + 30秒デバウンス /ingest)
                             #   proxy パスワード入りのため gitignore 済
  wiki-daemon_temp.ps1       # 共有用テンプレ (proxy 空欄)
  send-to-wiki.ps1           # Explorer「送る」→ raw/ にファイル移動
  install-daemon-task.ps1    # デーモンをログオン時自動起動に登録
  install-send-to.ps1        # 「送る」ショートカットを SendTo に配置
  uninstall.ps1              # 上記を撤去
  chrome-extension/
    manifest.json            # MV3
    background.js            # 右クリック3種 → POST http://localhost:7777/register
    icon.png
```

### セットアップ（3ステップ）

#### 1. デーモン本体を準備（proxy 設定）

`wiki-daemon.ps1` は gitignore されているので clone 後は存在しない。テンプレからコピーして proxy 設定を埋める:

```powershell
Copy-Item scripts\wiki-daemon_temp.ps1 scripts\wiki-daemon.ps1
notepad scripts\wiki-daemon.ps1
```

先頭の proxy ブロックを編集:

```powershell
$env:HTTP_PROXY  = "http://USER:PASSWORD@proxy.example.com:8088"
$env:HTTPS_PROXY = "http://USER:PASSWORD@proxy.example.com:8088"
$env:NO_PROXY    = "localhost,127.0.0.1,::1"
```

proxy 不要なら 3 行とも空文字 (`""`) か削除。

> **なぜ必要か**: タスクスケジューラから `-NoProfile` で起動されるため、PowerShell profile.ps1 の proxy 設定は継承されない。proxy 不通だと `claude.exe -p /ingest` が API 接続できずに無言ハングする。

#### 2. デーモンをログオン時自動起動に登録

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-daemon-task.ps1
Start-ScheduledTask -TaskName 'MyWikiDaemon'
```

タスク名は `MyWikiDaemon`、トリガーは `AtLogOn`。

#### 3. 「送る」ショートカットを配置

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-send-to.ps1
```

`%APPDATA%\Microsoft\Windows\SendTo\Wikiに登録.lnk` が作られる。

#### 4. Chrome 拡張をインストール

`chrome://extensions` を開き:

1. 「デベロッパーモード」を ON
2. 「パッケージ化されていない拡張機能を読み込む」をクリック
3. `C:\my-wiki\scripts\chrome-extension` を選択

### 動作の流れ

- **ブラウザ**: ページや選択範囲を右クリック → 「Wiki に登録 (このページ / 選択範囲 / このリンク先)」 → raw/ に `YYYY-MM-DD_HHmmss_<slug>.md` が生成される。
- **ローカルファイル**: Explorer でファイル右クリック → 送る → 「Wikiに登録」 → raw/ に **移動**（元ファイルは消える）。
- 直接 `raw/` にドラッグしても OK。
- いずれの経路でも raw/ への書き込みから **30 秒以内に追加がなければ**、デーモンが `claude -p "/ingest"` を 1 回起動する。ログは `.ingest.log` に出力。

### HTTP 受け口の使い方（直接呼び出し）

外部スクリプト等から直接登録する例:

```powershell
$body = @{
  source_type = "test"
  title       = "hello"
  url         = "https://example.com"
  content     = "本文テキスト"
} | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri http://localhost:7777/register `
  -ContentType 'application/json' -Body $body
```

健康チェック:

```powershell
Invoke-RestMethod http://localhost:7777/health
```

### 解除（アンインストール）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\uninstall.ps1
```

`MyWikiDaemon` タスク、`SendTo` 配下のショートカット、旧版残骸の「Wiki クイックメモ.lnk」が撤去される。Chrome 拡張は `chrome://extensions` から手動削除。

### デーモンの内部挙動

`scripts/wiki-daemon.ps1` は 3 つを同時に行う:

1. **HTTP サーバ**（`http://localhost:7777`）
   - `GET /health` … 死活確認
   - `POST /register` … JSON を受け取り、`raw/` に Markdown 化して保存
2. **FileSystemWatcher** で `raw/` を監視（`Created` イベントのみ）
3. **デバウンス**: 新規ファイル検出から **30 秒静まる**と、以下を起動

```powershell
claude -p /ingest --permission-mode bypassPermissions --output-format stream-json
```

二重起動防止に `.ingest.lock` を使う。30 分以上経過したロックは「stale」として自動削除。`.ingest.log` に進行状況が追記される（gitignore 済）。

代表的なログ行:

```
2026-05-13 12:15:03 daemon start: port=7777 debounce=30s rawDir=C:\my-wiki\raw
2026-05-13 12:15:03 backlog: 3 unprocessed file(s) — will trigger ingest in 30s
2026-05-13 12:15:12 register: 2026-05-13_121512_xxx.md (type=browser-page)
2026-05-13 12:15:42 ingest start
2026-05-13 12:15:43   tool: Read C:\my-wiki\raw\xxx.md
2026-05-13 12:15:50   tool: WebFetch https://...
2026-05-13 12:20:10 ingest exit=0
2026-05-13 12:20:10 ingest end
```

### トラブルシューティング

#### `/ingest` が始まったまま進まない

原因はほぼ proxy。`.ingest.log` で `ingest start` のあとに何分も無反応なら、まずハング中のプロセスを止めてロックを解放する:

```powershell
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'claude.*ingest' } |
  Select-Object ProcessId, CreationDate
Stop-Process -Id <PID> -Force
Remove-Item C:\my-wiki\.ingest.lock -ErrorAction SilentlyContinue
```

その後 `scripts\wiki-daemon.ps1` の proxy 設定を見直してからデーモンを再起動:

```powershell
Stop-ScheduledTask -TaskName MyWikiDaemon
Start-ScheduledTask -TaskName MyWikiDaemon
```

#### ポート 7777 が使えない / `cannot bind port`

別プロセスが占有している。多重起動の場合は不要な方を `Stop-Process` で落とす。

```powershell
netstat -ano | findstr :7777
```

#### Chrome 拡張が「登録失敗」と言う

デーモンが落ちている可能性が高い。拡張アイコンをクリックすると `/health` を叩くので切り分けに使える。

#### raw/ にファイルが残っているのに wiki/ に反映されない

1. `.ingest.log` で当該ファイルが `register:` / `watcher:` で検知されたか確認
2. ロックが残っていないか確認: `Get-Item C:\my-wiki\.ingest.lock`
3. デーモン再起動でバックログ検知（起動時に `sources:` 未記録ファイルを再キューする）

### バージョン管理上の注意

`.gitignore` で除外しているもの:

- `raw/*`（一次資料は外部公開しない）
- `wiki-daemon.ps1`（proxy パスワード入り）
- `.ingest.log` / `.ingest.lock`

> ⚠️ `git add .` は使わない方が安全。誤って `raw/` や proxy 情報を含むファイルを巻き込まないため、変更ファイルを個別に指定する。

## 関連

- [[Ingest-Query-Lint]] — このスクリプト群が自動で起動する 3 操作のうち Ingest の自動化レイヤー。
- [[3層構造]] — raw/ 層への投入経路を増やすのが本スクリプト群の目的。
- [[Wiki編集ルール]] — `/ingest` 起動後に AI が従う schema 層のルール。
- [[LLM-Wiki]]
