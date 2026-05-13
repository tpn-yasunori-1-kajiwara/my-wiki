# send-to-wiki.ps1
# Windows の「送る」メニューから呼ばれる想定。
# 引数で渡されたファイルを raw/ に移動 (タイムスタンプ付き)。元ファイルは消える。
#
# install-send-to.ps1 で %APPDATA%\Microsoft\Windows\SendTo\ に .lnk が置かれる。

param(
  [Parameter(ValueFromRemainingArguments=$true)]
  [string[]]$Paths
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$rawDir   = Join-Path $repoRoot 'raw'
$logFile  = Join-Path $repoRoot '.ingest.log'

if (-not (Test-Path $rawDir)) { New-Item -ItemType Directory -Path $rawDir | Out-Null }

function Write-Log($msg) {
  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') send-to: $msg" |
    Add-Content -LiteralPath $logFile -Encoding utf8
}

$ok = 0
$fail = 0
foreach ($p in $Paths) {
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { continue }
  try {
    $orig = Get-Item -LiteralPath $p
    $ts   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $base = $orig.BaseName -replace '[\\/:\*\?"<>\|]', '_'
    $ext  = $orig.Extension
    $name = "${ts}_${base}${ext}"
    $dest = Join-Path $rawDir $name
    Move-Item -LiteralPath $p -Destination $dest -Force
    Write-Log "moved $($orig.Name) -> $name"
    $ok++
  } catch {
    Write-Log "error on $p — $($_.Exception.Message)"
    $fail++
  }
}

if ($ok -gt 0 -or $fail -gt 0) {
  Add-Type -AssemblyName System.Windows.Forms
  $msg = "移動: $ok 件 / 失敗: $fail 件"
  [System.Windows.Forms.MessageBox]::Show($msg, 'Wiki に登録', 'OK', 'Information') | Out-Null
}
