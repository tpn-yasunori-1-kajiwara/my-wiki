# install-daemon-task.ps1
# wiki-daemon.ps1 をログオン時自動起動するタスクスケジューラ登録を作る。
# 旧 MyWikiIngestPoll (10分ポーリング) があれば停止・削除する。
#
# 実行:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-daemon-task.ps1
#
# 解除:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\uninstall.ps1

param(
  [string]$TaskName = 'MyWikiDaemon',
  [string]$OldTaskName = 'MyWikiIngestPoll'
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'wiki-daemon.ps1'
if (-not (Test-Path $scriptPath)) { throw "wiki-daemon.ps1 not found at $scriptPath" }

# 旧ポーリングタスクの解除
$old = Get-ScheduledTask -TaskName $OldTaskName -ErrorAction SilentlyContinue
if ($old) {
  Write-Host "Removing old polling task: $OldTaskName"
  Stop-ScheduledTask  -TaskName $OldTaskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $OldTaskName -Confirm:$false
}

$action = New-ScheduledTaskAction `
  -Execute 'powershell.exe' `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

# ログオンの 3 分後に起動する。
# ログオン直後はウイルス対策 (Trend Micro Apex One) のスキャン・挙動監視が集中し、
# 起動直後のデーモンが強制終了 (0xC000013A) される事象が発生したため (2026-08-12 / 08-14)。
$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$logonTrigger.Delay = 'PT3M'

# ウォッチドッグ: 30 分ごとに起動を試みる。
# デーモン生存中は MultipleInstances=IgnoreNew により無視され（副作用なし）、
# 何らかの理由で死んでいたら 30 分以内に自動復活する（自己回復）。
# ※ 万一トリガーが同時多発してもデーモン側がポート使用中を検知して exit 0 する。
$watchdogTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date `
  -RepetitionInterval (New-TimeSpan -Minutes 30) `
  -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
  -StartWhenAvailable `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -RestartCount 3 `
  -RestartInterval (New-TimeSpan -Minutes 1)

$principal = New-ScheduledTaskPrincipal `
  -UserId "$env:USERDOMAIN\$env:USERNAME" `
  -LogonType Interactive `
  -RunLevel Limited

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger $logonTrigger, $watchdogTrigger `
  -Settings $settings `
  -Principal $principal `
  -Description 'My Wiki daemon: HTTP register (localhost:7777) + raw/ watcher + auto /ingest' `
  -Force | Out-Null

Write-Host ""
Write-Host "Registered: $TaskName"
Write-Host "Script    : $scriptPath"
Write-Host ""
Write-Host "今すぐ起動: Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "状態確認  : Get-ScheduledTask -TaskName '$TaskName'"
Write-Host "ログ      : $((Split-Path -Parent $PSScriptRoot))\.ingest.log"
Write-Host "解除      : scripts\uninstall.ps1"
