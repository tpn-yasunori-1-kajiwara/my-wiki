# 個人用 LLM Wiki

テキスト資料を一次資料として、自分専用の知識ベース（wiki）を AI（Claude Code）で育てるためのリポジトリ。
資料中に URL があれば AI が自動取得して反映する。

- **raw/** に投入されたテキストを、AI が概念ごとに整理して **wiki/** に書き出す
- raw/ への投入は **4 経路**（ドラッグ、エクスプローラ「送る」、Chrome 拡張、HTTP API）
- 投入後 30 秒で自動的に `/ingest` が走る常駐デーモン付き
- AI の振る舞いルールは `CLAUDE.md` に集約

---

## ディレクトリ構成

```
my-wiki/
├── raw/                          # 一次資料の投入先 (不変層 / git 管理外)
├── wiki/                         # AI が管理する Markdown 知識ベース
├── scripts/
│   ├── wiki-daemon.ps1           # ★ 本番用 (proxy 入り / gitignore 済)
│   ├── wiki-daemon_temp.ps1      # ★ 共有用テンプレ (proxy 空欄)
│   ├── install-daemon-task.ps1   # デーモンをログオン時自動起動に登録
│   ├── install-send-to.ps1       # 「送る」メニュー .lnk を配置
│   ├── send-to-wiki.ps1          # 「送る」のハンドラ (ファイルを raw/ へ移動)
│   ├── uninstall.ps1             # タスク + .lnk を全部撤去
│   └── chrome-extension/         # 右クリック「Wiki に登録」拡張
├── CLAUDE.md                     # AI 向け運用ルール (schema 層)
├── README.md                     # このファイル
└── .gitignore                    # raw/, .ingest.log, wiki-daemon.ps1 など
```

---

## 前提

- Windows 10 / 11
- PowerShell 5.1 (Windows 標準) または PowerShell 7
- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code) インストール済み (`claude.exe` が PATH に存在)
- Anthropic API 認証済み（`claude` 単体で起動して認証フローを通しておく）
- 社内 proxy 環境で使う場合は proxy 認証情報

---

## セットアップ（git clone から）

### 1. リポジトリを取得

```powershell
cd C:\
git clone <repo-url> my-wiki
cd C:\my-wiki
```

### 2. デーモン本体を準備（proxy 設定）

`wiki-daemon.ps1` は **gitignore されている** ので clone 後は存在しない。テンプレからコピーして proxy 設定を埋める。

```powershell
Copy-Item scripts\wiki-daemon_temp.ps1 scripts\wiki-daemon.ps1
notepad scripts\wiki-daemon.ps1
```

ファイル先頭付近の以下のブロックを編集:

```powershell
# === Proxy (auto) ===
$env:HTTP_PROXY  = "http://USER:PASSWORD@proxy.example.com:8088"
$env:HTTPS_PROXY = "http://USER:PASSWORD@proxy.example.com:8088"
$env:NO_PROXY    = "localhost,127.0.0.1,::1"
```

- **proxy を使わない環境**: 3 行とも空文字 (`""`) にするか、ブロックごと削除。
- **proxy を使う環境**: ユーザ名・パスワードを `:` で区切り、`@` の前に置く。`#` `=` `&` などは URL エンコードする（例: `Yasu=0803` → そのまま使えるが `:` `@` `/` `?` `#` は要エンコード）。

> **なぜ必要か**: デーモンはタスクスケジューラから `-NoProfile` で起動されるため、PowerShell プロファイル (`Microsoft.PowerShell_profile.ps1`) で設定した `$env:HTTP_PROXY` が継承されない。proxy 不通だと `claude.exe -p /ingest` が API 接続に失敗して無言ハングする。

### 3. デーモンをログオン時自動起動に登録

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-daemon-task.ps1
```

- タスク名: `MyWikiDaemon`
- トリガー: **ログオン時**（PC 電源 ON → サインイン後に自動起動）
- ウィンドウ非表示・実行時間制限なし・失敗時 3 回まで再起動
- 旧 `MyWikiIngestPoll`（10 分ポーリング）があれば自動撤去

今すぐ起動（次回ログオンを待たずに）:

```powershell
Start-ScheduledTask -TaskName MyWikiDaemon
```

動作確認:

```powershell
Invoke-RestMethod http://localhost:7777/health
# → status=ok, port=7777
```

### 4. 「送る」メニューに .lnk を配置

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-send-to.ps1
```

`%APPDATA%\Microsoft\Windows\SendTo\Wikiに登録.lnk` が作られる。

### 5. Chrome 拡張をロード

1. Chrome で `chrome://extensions` を開く
2. 右上の **デベロッパーモード** を ON
3. **パッケージ化されていない拡張機能を読み込む** をクリック
4. `C:\my-wiki\scripts\chrome-extension\` フォルダを選択

完了後、ページ右クリックで以下 3 つが出れば成功:
- Wiki に登録 (このページ)
- Wiki に登録 (選択範囲)
- Wiki に登録 (このリンク先)

拡張アイコンクリックで `/health` を叩いて動作確認できる。

---

## 使い方：raw/ への 4 つの投入経路

すべて最終的に `raw/` への新規ファイル作成 → デーモンが検知 → 30 秒デバウンス後に `claude -p /ingest` 自動起動、という同じパイプラインに合流する。

### A. 直接ドラッグ
エクスプローラで `raw/` にファイルをドロップ。任意の `.md` / `.txt` / `.html` / `.pdf` / `.json` / `.csv`。

### B. エクスプローラ「送る」
ファイルを右クリック → **送る → Wikiに登録**。
- 元ファイルは **`raw/` に移動**される（コピーではない）。
- 移動後にタイムスタンプ付き名前 `YYYY-MM-DD_HHmmss_<元ファイル名>` になる。
- 完了時に「移動: N 件 / 失敗: 0 件」の MessageBox。

### C. Chrome 拡張
- **このページ** … URL + ページタイトル
- **選択範囲** … URL + 選択テキスト
- **このリンク先** … リンク先 URL のみ

すべて `POST http://localhost:7777/register` で送信される（デーモン未起動だとエラー通知）。

### D. HTTP API
任意のスクリプトから:

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

---

## デーモンの挙動

`scripts/wiki-daemon.ps1` は 3 つを同時に行う:

1. **HTTP サーバ** (`http://localhost:7777`)
   - `GET /health` … 死活確認
   - `POST /register` … JSON 受け取り、`raw/` に Markdown 化して保存
2. **FileSystemWatcher** で `raw/` 監視（`Created` イベントのみ）
3. **デバウンス**: 新規ファイル検出から **30 秒静まる** と `claude -p /ingest --permission-mode bypassPermissions --output-format stream-json` を起動

二重起動防止に `.ingest.lock` を使用。30 分以上経過したロックは「stale」として自動削除。

### ログ

`.ingest.log` に追記される（gitignore 済）。代表的な行:

```
2026-05-13 12:15:03 daemon start: port=7777 debounce=30s rawDir=C:\my-wiki\raw
2026-05-13 12:15:03 backlog: 3 unprocessed file(s) — will trigger ingest in 30s
2026-05-13 12:15:12 register: 2026-05-13_121512_xxx.md (type=browser-page)
2026-05-13 12:15:42 ingest start
2026-05-13 12:15:43   tool: Read C:\my-wiki\raw\xxx.md
2026-05-13 12:15:50   tool: WebFetch https://...
...
2026-05-13 12:20:10 ingest exit=0
2026-05-13 12:20:10 ingest end
```

---

## スラッシュコマンド

| コマンド          | 説明 |
|-------------------|------|
| `/ingest`         | `raw/` の未処理ファイルを読み、URL を辿り、`wiki/` に反映 |
| `/query <質問>`   | wiki に問い合わせ。任意で回答を wiki に書き戻し |
| `/lint`           | wiki の品質チェック（孤立、矛盾、重複、dead source、未処理 raw） |

手動で起動するには:

```powershell
cd C:\my-wiki
claude
```
→ プロンプトで `/ingest` などを入力。

---

## トラブルシューティング

### `/ingest` が始まったまま進まない
原因はほぼ proxy。`.ingest.log` で `ingest start` のあとに何分も無反応なら:

1. ハング中のプロセスを探して止める
   ```powershell
   Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'claude.*ingest' } |
     Select-Object ProcessId, CreationDate
   Stop-Process -Id <PID> -Force
   Remove-Item C:\my-wiki\.ingest.lock -ErrorAction SilentlyContinue
   ```
2. `scripts\wiki-daemon.ps1` の proxy 設定を見直す
3. デーモンを再起動
   ```powershell
   Stop-ScheduledTask -TaskName MyWikiDaemon
   Start-ScheduledTask -TaskName MyWikiDaemon
   ```

### ポート 7777 が使えない / `cannot bind port`
別プロセスが占有している。`netstat -ano | findstr :7777` で確認。デーモンの多重起動だったら不要な方を `Stop-Process` で落とす。

### Chrome 拡張が「登録失敗」と言う
デーモンが落ちている可能性が高い。拡張アイコンをクリックすると `/health` を叩くのでそこで切り分け。

### raw/ にファイルが残っているのに wiki/ に反映されない
1. `.ingest.log` で当該ファイルが `register:` / `watcher:` で検知されたか確認
2. ロックが残っていないか確認: `Get-Item C:\my-wiki\.ingest.lock`
3. デーモン再起動でバックログ検知（起動時に `sources:` 未記録ファイルを再キューする）

---

## メンテナンス

### すべての自動化を撤去

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\uninstall.ps1
```
これで:
- `MyWikiDaemon` タスク解除
- `SendTo\Wikiに登録.lnk` 削除
- 旧版残骸の `Wiki クイックメモ.lnk` も削除（あれば）

Chrome 拡張は `chrome://extensions` から手動削除。

### proxy パスワード変更

`scripts/wiki-daemon.ps1` を編集 → デーモン再起動:
```powershell
Stop-ScheduledTask -TaskName MyWikiDaemon
Start-ScheduledTask -TaskName MyWikiDaemon
```

---

## バージョン管理

```powershell
cd C:\my-wiki
git status
git add wiki/ scripts/wiki-daemon_temp.ps1 ...   # 個別に追加するのが安全
git commit -m "..."
git push
```

`.gitignore` で除外しているもの:
- `raw/*`（一次資料は外部公開しない）
- `wiki-daemon.ps1`（proxy パスワード入り）
- `.ingest.log` / `.ingest.lock`

> ⚠️ **`git add .` は使わない方が安全**。誤って `raw/` や個人情報を含むファイルを巻き込まないため、変更ファイルを個別に指定する。

---

## 仕組み

- `raw/`（一次資料）と `wiki/`（整理済み）を分離。
- `raw/` は **不変**。一度入れたら削除も改名もしない（`CLAUDE.md` ルール）。
- 処理済み判定は wiki ページの `sources:` フロントマターで行う。
- URL が本文中にあれば AI が **WebFetch** で取得して内容を反映、`references:` に記録。
- コマンド・コードブロック・設定例は要約せず原文ママで wiki に保存する（`CLAUDE.md` ルール）。
- wiki は **テキストのみ**（画像埋め込みなし）。

詳細な振る舞いルールは [`CLAUDE.md`](CLAUDE.md) を参照。

---

## 参考

- 元アイデア: https://note.com/yasuhitoo/n/naf7246ce43cc
