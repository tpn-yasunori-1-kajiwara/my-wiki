# install-send-to.ps1
# %APPDATA%\Microsoft\Windows\SendTo に「Wikiに登録.lnk」を作成する。
# これでエクスプローラーでファイルを右クリック→送る→Wikiに登録 で
# scripts\send-to-wiki.ps1 が呼ばれ、raw/ に移動される。

$ErrorActionPreference = 'Stop'
$sendToDir = [Environment]::GetFolderPath('SendTo')

$shell = New-Object -ComObject WScript.Shell

function New-LnkTo {
  # 注意: $Args は PowerShell の自動変数なのでパラメータ名に使えない (常に空になる)。
  param([string]$Path, [string]$Target, [string]$Arguments, [string]$WorkingDir, [string]$Description)
  $sc = $shell.CreateShortcut($Path)
  $sc.TargetPath       = $Target
  $sc.Arguments        = $Arguments
  $sc.WorkingDirectory = $WorkingDir
  $sc.Description      = $Description
  $sc.Save()
  Write-Host "Created: $Path"
}

# Send To: ファイルを raw/ に移動
$sendToHandler = Join-Path $PSScriptRoot 'send-to-wiki.ps1'
New-LnkTo `
  -Path       (Join-Path $sendToDir 'Wikiに登録.lnk') `
  -Target     'powershell.exe' `
  -Arguments  "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$sendToHandler`"" `
  -WorkingDir $PSScriptRoot `
  -Description 'Wiki の raw/ にファイルを移動'

Write-Host ""
Write-Host "完了。エクスプローラでファイルを右クリック → 送る → Wikiに登録 で raw/ に移動されます。"
