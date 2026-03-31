cd $env:TEMP

$installDir = Join-Path $HOME "browser-files"
$interfaceFile = Join-Path $installDir "interfaceGui.ps1"
$urlInterface = "https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/refs/heads/master/interfaceGUI.ps1"

Write-Host "Fazendo a atualizacao dos arquivos de Browser-Files..." -ForegroundColor Cyan

Invoke-WebRequest -Uri $urlInterface -OutFile $interfaceFile

write-host "`nAutalizacoes concluidas, pressione Enter para abrir." -Foregroundcolor Green
Read-Host | Out-Null
