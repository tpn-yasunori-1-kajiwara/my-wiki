# ingest-poll.ps1
# Polls raw/ for unprocessed text resources and triggers Claude Code /ingest.
# Designed for Windows Task Scheduler (every N minutes).
#
# Manual test:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ingest-poll.ps1
#
# Behavior:
#   1. Lists files in raw/ (any extension; .gitkeep excluded).
#   2. For each, greps wiki/*.md for the filename in `sources:` lines.
#      Files not yet referenced are considered unprocessed.
#   3. If any unprocessed file exists, invokes `claude -p` headlessly,
#      asking it to follow CLAUDE.md and .claude/commands/ingest.md.
#   4. Uses .ingest.lock to prevent overlapping runs (>30min lock is stale).
#   5. Logs to .ingest.log.

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$lockFile = Join-Path $repoRoot '.ingest.lock'
$logFile  = Join-Path $repoRoot '.ingest.log'

function Write-Log($msg) {
  "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Add-Content -LiteralPath $logFile -Encoding utf8
}

# Stale-lock cleanup (30 min)
if (Test-Path $lockFile) {
  $age = (Get-Date) - (Get-Item $lockFile).LastWriteTime
  if ($age.TotalMinutes -lt 30) {
    Write-Log ("skip: another instance running (lock age: {0}min)" -f [math]::Round($age.TotalMinutes, 1))
    exit 0
  }
  Write-Log ("warn: stale lock removed (age: {0}min)" -f [math]::Round($age.TotalMinutes, 1))
  Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
}

# List raw files (exclude .gitkeep, dotfiles)
$rawDir = Join-Path $repoRoot 'raw'
$rawFiles = @(Get-ChildItem -LiteralPath $rawDir -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -ne '.gitkeep' -and -not $_.Name.StartsWith('.') })
if ($rawFiles.Count -eq 0) {
  exit 0
}

# Find unprocessed: filename not in any wiki/*.md sources: line.
$wikiDir = Join-Path $repoRoot 'wiki'
$unprocessed = @()
foreach ($f in $rawFiles) {
  $name = $f.Name
  $hit = $null
  if (Test-Path $wikiDir) {
    $hit = Get-ChildItem -LiteralPath $wikiDir -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue |
           Select-String -SimpleMatch -Pattern $name -List
  }
  if (-not $hit) { $unprocessed += $f }
}
if ($unprocessed.Count -eq 0) {
  exit 0
}

Write-Log ("start: {0} unprocessed file(s): {1}" -f $unprocessed.Count, (($unprocessed | Select-Object -ExpandProperty Name) -join ', '))
New-Item -ItemType File -Path $lockFile -Force | Out-Null

try {
  Set-Location -LiteralPath $repoRoot
  $prompt = @'
Read CLAUDE.md and .claude/commands/ingest.md to refresh the rules,
then perform the full ingest workflow for every unprocessed file in raw/
(files whose name is not yet listed in any wiki/*.md `sources:` line).
Follow CLAUDE.md strictly: do not delete/move raw files,
use text-only wiki pages, and WebFetch any URLs found in the source text.
End with a brief summary line per file.
'@

  $output = & claude -p $prompt 2>&1 | Out-String
  $exitCode = $LASTEXITCODE
  Write-Log ("claude exit={0}" -f $exitCode)
  ($output -split "`r?`n") | ForEach-Object { if ($_.Trim()) { Write-Log ("  {0}" -f $_) } }
} catch {
  Write-Log ("error: {0}" -f $_.Exception.Message)
} finally {
  Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
  Write-Log "end"
}
