# muda de pasta para executar o script
cd $env:TEMP

# uninstall.ps1
$installDir = Join-Path $env:APPDATA "inventory-machine"

# 1. Remove do PATH do UsuÃ¡rio
$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = ($oldPath -split ';' | Where-Object { $_ -ne $installDir }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# 2. Remove a pasta fÃ­sica
if (Test-Path $installDir) {
    Remove-Item -Path $installDir -Recurse -Force
}

Write-Host "`ninventory-machine foi removido com sucesso." -ForegroundColor Green
Write-Host "`nRemovendo o Atalho na Area de trabalho...." -Foreground Yellow

$removeLnk = Join-Path $env:USERPROFILE "Desktop"
$lnkGui = Join-Path $removeLnk "inventario.lnk"
Remove-Item $lnkGui -Recurse -Force

Write-Host "`nAtalho removido com sucesso." -ForegroundColor Green
Write-Host "`nPressione Enter para fechar." -Foreground Yellow