cd $env:TEMP

$installDir = Join-Path $env:APPDATA "browser-files"
$interfaceFile = Join-Path $installDir "interfaceGui.ps1"
$urlInterface = "https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/refs/heads/master/interfaceGUI.ps1"

Write-Host "Fazendo a atualizacao dos arquivos de Browser-Files..." -ForegroundColor Cyan

Remove-Item $interfaceFile -Recurse -Force
Write-Host "`nBaixando atualizacoes..." -ForegroundColor Yellow

timeout /T 5
Invoke-WebRequest -Uri $urlInterface -OutFile $interfaceFile

Write-Host "`nAtualizando o atalho na Area de Trabalho..." -ForegroundColor Cyan

# Remocao do antigo atalho

$removeLnk = Join-Path $env:USERPROFILE "Desktop"
$lnkGui = Join-Path $removeLnk "InterfaceGUi.lnk"
Remove-Item $lnkGui -Recurse -Force

# criacao do atalho na area de trabalho atualizado

$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [System.Environment]::GetFolderPath("Desktop")

# 1. Definimos o caminho completo do atalho primeiro
$ShortcutPath = Join-Path $DesktopPath "InterfaceGUi.lnk"

# 2. Criamos o objeto de atalho
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)

# 3. Configuramos as propriedades
$Shortcut.TargetPath = "powershell.exe"
# Usamos "" para garantir que o caminho do arquivo fique entre aspas mesmo com espaços
# $Shortcut.Arguments = "-WindowStyle Hidden -File ""$installDir\interfaceGui.ps1"""
$Shortcut.Arguments = "-File ""$installDir\interfaceGui.ps1"""
$Shortcut.WorkingDirectory = $installDir
$Shortcut.IconLocation = "shell32.dll,21" 
$Shortcut.Save()

write-host "`nAutalizacoes concluidas, pressione Enter para fechar o terminal." -Foregroundcolor Green
Read-Host | Out-Null
