# wiki-daemon.ps1
# 長期常駐プロセス。3つの仕事をする:
#   1. HTTPサーバ (localhost:7777) で POST /register を受け、raw/ にファイル化
#   2. raw/ を FileSystemWatcher で監視
#   3. 新規ファイル検出から $DebounceSeconds 秒静まったら claude -p '/ingest' を起動
#
# 手動起動:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\wiki-daemon.ps1
#
# スケジュール起動 (ログオン時):
#   scripts\install-daemon-task.ps1
#
# 動作確認:
#   curl http://localhost:7777/health
#   curl -X POST http://localhost:7777/register -H "Content-Type: application/json" `
#        -d '{"source_type":"test","title":"hello","url":"https://example.com","content":"test"}'

param(
  [int]$Port = 7777,
  [int]$DebounceSeconds = 30
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$rawDir   = Join-Path $repoRoot 'raw'
$logFile  = Join-Path $repoRoot '.ingest.log'
$lockFile = Join-Path $repoRoot '.ingest.lock'

# === Proxy (auto) ===
# タスクスケジューラから -NoProfile で起動されるため、PowerShell profile.ps1 の
# proxy 設定はここに継承されない。子プロセス (claude.exe) が Anthropic API に
# 出られないとハングするので明示的に設定する。
# NOTE: パスワードを含むので、このファイルを公開リポジトリに push しないこと。
$env:HTTP_PROXY  = "XXXXX"
$env:HTTPS_PROXY = "XXXXX"
$env:NO_PROXY    = "localhost,127.0.0.1,::1"

function Write-Log($msg) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
  try { $line | Add-Content -LiteralPath $logFile -Encoding utf8 } catch {}
  Write-Host $line
}

function Sanitize-Slug([string]$s) {
  if ([string]::IsNullOrWhiteSpace($s)) { return 'untitled' }
  $s = $s -replace '[\\/:\*\?"<>\|\r\n\t]', '_'
  $s = $s -replace '\s+', '_'
  $s = $s.Trim('_')
  if ($s.Length -gt 50) { $s = $s.Substring(0, 50) }
  if ([string]::IsNullOrWhiteSpace($s)) { return 'untitled' }
  return $s
}

function Write-RawFile {
  param(
    [string]$Title,
    [string]$Url,
    [string]$Content,
    [string]$SourceType
  )
  $ts = Get-Date -Format 'yyyy-MM-dd_HHmmss'
  $slug = Sanitize-Slug $Title
  if ($slug -eq 'untitled' -and $Url) { $slug = Sanitize-Slug ($Url -replace '^https?://', '') }
  $name = "${ts}_${slug}.md"
  $path = Join-Path $rawDir $name

  $lines = New-Object System.Collections.Generic.List[string]
  if ($Title) { $lines.Add("# $Title"); $lines.Add('') }
  if ($Url)   { $lines.Add("Source URL: $Url") }
  $lines.Add("Captured: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
  if ($SourceType) { $lines.Add("Source type: $SourceType") }
  $lines.Add('')
  if ($Content) { $lines.Add($Content) }

  ($lines -join "`r`n") | Out-File -LiteralPath $path -Encoding utf8
  return $name
}

function Send-JsonResponse {
  param($Response, [int]$Status, $Object)
  $json = $Object | ConvertTo-Json -Compress
  $bytes = [Text.Encoding]::UTF8.GetBytes($json)
  $Response.StatusCode = $Status
  $Response.ContentType = 'application/json; charset=utf-8'
  $Response.Headers.Add('Access-Control-Allow-Origin', '*')
  $Response.ContentLength64 = $bytes.Length
  $Response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Handle-Request($context) {
  $req = $context.Request
  $res = $context.Response
  try {
    if ($req.HttpMethod -eq 'OPTIONS') {
      $res.Headers.Add('Access-Control-Allow-Origin', '*')
      $res.Headers.Add('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
      $res.Headers.Add('Access-Control-Allow-Headers', 'Content-Type')
      $res.StatusCode = 204
      return
    }
    if ($req.HttpMethod -eq 'GET' -and $req.Url.AbsolutePath -eq '/health') {
      Send-JsonResponse $res 200 @{ status = 'ok'; port = $Port }
      return
    }
    if ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/register') {
      $reader = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
      $bodyText = $reader.ReadToEnd()
      $data = $bodyText | ConvertFrom-Json
      $name = Write-RawFile -Title $data.title -Url $data.url -Content $data.content -SourceType $data.source_type
      Write-Log "register: $name (type=$($data.source_type))"
      Send-JsonResponse $res 200 @{ status = 'ok'; file = $name }
      return
    }
    Send-JsonResponse $res 404 @{ status = 'error'; message = 'not found' }
  } catch {
    Write-Log "request error: $($_.Exception.Message)"
    try { Send-JsonResponse $res 500 @{ status = 'error'; message = $_.Exception.Message } } catch {}
  } finally {
    try { $res.OutputStream.Close() } catch {}
  }
}

function Trigger-Ingest {
  if (Test-Path $lockFile) {
    $age = (Get-Date) - (Get-Item $lockFile).LastWriteTime
    if ($age.TotalMinutes -lt 30) {
      Write-Log "ingest skipped: lock present (age $([math]::Round($age.TotalMinutes,1))min)"
      return
    }
    Write-Log "warn: stale lock removed"
    Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType File -Path $lockFile -Force | Out-Null
  Write-Log "ingest start"
  try {
    Set-Location -LiteralPath $repoRoot
    # /ingest はプロジェクトに登録されたスキル。-p (非対話) で叩く時は
    # 必ず --permission-mode bypassPermissions を付けないと、ツール許可待ちで永久に固まる。
    # --output-format stream-json で各ツール呼び出しを JSON 1 行ずつ受け取り、進捗を可視化する。
    & claude -p '/ingest' `
        --permission-mode bypassPermissions `
        --verbose `
        --output-format stream-json 2>&1 |
      ForEach-Object {
        if (-not $_ -or -not "$_".Trim()) { return }
        $raw = "$_"
        try {
          $j = $raw | ConvertFrom-Json -ErrorAction Stop
          $summary = switch ($j.type) {
            'system' { "system($($j.subtype))" }
            'assistant' {
              $parts = @()
              foreach ($c in $j.message.content) {
                if ($c.type -eq 'text') {
                  $t = ($c.text -replace '\s+', ' ').Trim()
                  if ($t.Length -gt 160) { $t = $t.Substring(0,160) + '...' }
                  if ($t) { $parts += "text: $t" }
                } elseif ($c.type -eq 'tool_use') {
                  $tn = $c.name
                  $hint = ''
                  if ($c.input.file_path)  { $hint = " $($c.input.file_path)" }
                  elseif ($c.input.pattern) { $hint = " /$($c.input.pattern)/" }
                  elseif ($c.input.url)     { $hint = " $($c.input.url)" }
                  $parts += "tool: $tn$hint"
                }
              }
              if ($parts.Count -gt 0) { ($parts -join ' | ') } else { 'assistant' }
            }
            'user' {
              $tools = @($j.message.content | Where-Object { $_.type -eq 'tool_result' })
              if ($tools.Count -gt 0) { "tool_result x$($tools.Count)" } else { 'user' }
            }
            'result' {
              $r = ("$($j.result)" -replace '\s+', ' ').Trim()
              if ($r.Length -gt 200) { $r = $r.Substring(0,200) + '...' }
              "result($($j.subtype)): $r"
            }
            default { "$($j.type)" }
          }
          Write-Log "  $summary"
        } catch {
          Write-Log "  $raw"
        }
      }
    Write-Log "ingest exit=$LASTEXITCODE"
  } catch {
    Write-Log "ingest error: $($_.Exception.Message)"
  } finally {
    Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    Write-Log "ingest end"
  }
}

# ---------- bootstrap ----------
if (-not (Test-Path $rawDir)) { New-Item -ItemType Directory -Path $rawDir | Out-Null }

$watcher = New-Object IO.FileSystemWatcher
$watcher.Path = $rawDir
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'
$watcher.EnableRaisingEvents = $true
Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier 'WikiRawCreated' | Out-Null

$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try {
  $listener.Start()
} catch {
  Write-Log "fatal: cannot bind port $Port — $($_.Exception.Message)"
  throw
}
Write-Log "daemon start: port=$Port debounce=${DebounceSeconds}s rawDir=$rawDir"

# 起動時バックログ検出: raw/ にあるが wiki/*.md の sources: に未記録のファイルがあれば、
# 30 秒後に一回だけ /ingest を起動するよう $lastChange を仕掛ける。
$wikiDir = Join-Path $repoRoot 'wiki'
$rawFiles = @(Get-ChildItem -LiteralPath $rawDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -ne '.gitkeep' -and -not $_.Name.StartsWith('.') })
$backlog = @()
foreach ($f in $rawFiles) {
  $hit = $null
  if (Test-Path $wikiDir) {
    $hit = Get-ChildItem -LiteralPath $wikiDir -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue |
           Select-String -SimpleMatch -Pattern $f.Name -List
  }
  if (-not $hit) { $backlog += $f.Name }
}
if ($backlog.Count -gt 0) {
  Write-Log "backlog: $($backlog.Count) unprocessed file(s) — will trigger ingest in ${DebounceSeconds}s"
  $lastChange = Get-Date
} else {
  $lastChange = $null
}

$pendingAsync = $listener.BeginGetContext($null, $null)

try {
  while ($listener.IsListening) {
    # 1. Drain watcher events
    $events = @(Get-Event -SourceIdentifier 'WikiRawCreated' -ErrorAction SilentlyContinue)
    foreach ($e in $events) {
      $eArgs = $e.SourceEventArgs
      Remove-Event -EventIdentifier $e.EventIdentifier
      if (-not $eArgs) { continue }
      $name = $eArgs.Name
      if (-not $name) { continue }
      if ($name -eq '.gitkeep' -or $name.StartsWith('.')) { continue }
      $lastChange = Get-Date
      Write-Log "watcher: created $name"
    }

    # 2. Debounce check
    if ($lastChange -and ((Get-Date) - $lastChange).TotalSeconds -ge $DebounceSeconds) {
      $lastChange = $null
      Trigger-Ingest
    }

    # 3. HTTP (wait up to 1s for next request)
    if ($pendingAsync.AsyncWaitHandle.WaitOne(1000)) {
      try {
        $context = $listener.EndGetContext($pendingAsync)
        Handle-Request $context
      } catch {
        Write-Log "http error: $($_.Exception.Message)"
      }
      $pendingAsync = $listener.BeginGetContext($null, $null)
    }
  }
} finally {
  try { $listener.Stop() } catch {}
  try { $listener.Close() } catch {}
  try { Unregister-Event -SourceIdentifier 'WikiRawCreated' -ErrorAction SilentlyContinue } catch {}
  try { $watcher.Dispose() } catch {}
  Write-Log "daemon stop"
}
