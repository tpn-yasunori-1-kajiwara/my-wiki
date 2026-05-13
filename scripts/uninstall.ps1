# uninstall.ps1
# install-* で作ったもの (タスクスケジューラ、SendTo ショートカット) を撤去する。
# 旧版で配置されていたクイックメモ用ショートカットも残骸として消す。

$ErrorActionPreference = 'Continue'

foreach ($t in 'MyWikiDaemon','MyWikiIngestPoll') {
  $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
  if ($task) {
    Write-Host "Removing task: $t"
    Stop-ScheduledTask  -TaskName $t -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $t -Confirm:$false
  }
}

$sendToDir   = [Environment]::GetFolderPath('SendTo')
$desktopDir  = [Environment]::GetFolderPath('Desktop')
$programsDir = [Environment]::GetFolderPath('Programs')

foreach ($p in @(
  (Join-Path $sendToDir   'Wikiに登録.lnk'),
  (Join-Path $desktopDir  'Wiki クイックメモ.lnk'),   # 旧版残骸
  (Join-Path $programsDir 'Wiki クイックメモ.lnk')    # 旧版残骸
)) {
  if (Test-Path -LiteralPath $p) {
    Write-Host "Removing: $p"
    Remove-Item -LiteralPath $p -Force
  }
}

Write-Host ""
Write-Host "完了。Chrome 拡張を入れている場合は手動で chrome://extensions から削除してください。"
