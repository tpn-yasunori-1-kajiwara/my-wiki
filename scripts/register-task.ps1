# register-task.ps1
# Registers a Windows Task Scheduler entry that runs ingest-poll.ps1 every N minutes.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\register-task.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\register-task.ps1 -IntervalMinutes 5
#
# Remove:
#   Unregister-ScheduledTask -TaskName 'MyWikiIngestPoll' -Confirm:$false
#
# Requires no admin privileges (registers as the current user).

param(
  [int]$IntervalMinutes = 10,
  [string]$TaskName = 'MyWikiIngestPoll'
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'ingest-poll.ps1'
if (-not (Test-Path $scriptPath)) {
  throw "ingest-poll.ps1 not found at $scriptPath"
}

$action = New-ScheduledTaskAction `
  -Execute 'powershell.exe' `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger `
  -Once -At (Get-Date).AddMinutes(1) `
  -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
  -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
  -StartWhenAvailable `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 25)

$principal = New-ScheduledTaskPrincipal `
  -UserId "$env:USERDOMAIN\$env:USERNAME" `
  -LogonType Interactive `
  -RunLevel Limited

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Principal $principal `
  -Description "Polls C:\my-wiki\raw\ for new text resources and triggers Claude Code /ingest." `
  -Force | Out-Null

Write-Host "Registered: $TaskName"
Write-Host "Interval  : every $IntervalMinutes minutes"
Write-Host "Script    : $scriptPath"
Write-Host ""
Write-Host "Check status: Get-ScheduledTask -TaskName '$TaskName'"
Write-Host "Run now    : Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "Unregister : Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
