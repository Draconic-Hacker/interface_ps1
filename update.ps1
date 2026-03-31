cd $env:TEMP

taskkill /fi "windowtitle eq Meu Gerenciador" /f

cls

$installDir = Join-Path $HOME "browser-files"
$batFile = Join-Path $installDir "navegador.bat"
$urlMain = "https://raw.githubusercontent.com/Draconic-Hacker/scripts-batch/refs/heads/master/navegador.bat"

Write-Host "Fazendo a atualizacao dos arquivos de Browser-Files..." -ForegroundColor Cyan
write-host "`nAutalizacoes concluidas, pressione Enter para abrir." -Foregroundcolor Green
Read-Host | Out-Null

$navegadorContent = Invoke-WebRequest -Uri $urlMain -UseBasicParsing
[System.IO.File]::WriteAllText($batFile, $navegadorContent.Content, [System.Text.Encoding]::ASCII)

start cmd "/k cd $home/browser-files & navegador.bat"
