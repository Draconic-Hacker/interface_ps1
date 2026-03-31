# muda de pasta para executar o script
cd $env:TEMP

# fecha a janela do navegador.bat aberta para evitar erro de conflito
# taskkill /fi "windowtitle eq Meu Gerenciador" /f >nul

# uninstall.ps1
$installDir = Join-Path $env:APPDATA "browser-files"

# 1. Remove do PATH do Usuário
$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = ($oldPath -split ';' | Where-Object { $_ -ne $installDir }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# 2. Remove a pasta física
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "browser-files foi removido com sucesso." -ForegroundColor Green
Write-Host "`nPressione Enter para fechar." -Foreground Yellow
Read-Host | Out-Null
exit
