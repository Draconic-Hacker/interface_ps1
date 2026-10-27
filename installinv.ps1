$installDir = Join-Path $env:APPDATA "inventory-machine"


$initFile = Join-Path $installDir "Info-System-lock.bat"
$uninstallFile = Join-Path $installDir "uninstall.ps1"


$urlinitFile = "https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/3eec0f9ae620a20bb60adf33a403ca9415aecae8/Info-System-lock.bat"
$urlUninstall = "https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/refs/heads/dev-inv/uninstall.ps1"


# 1. Cria a pasta se nÃ£o existir
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}


# 2. Baixa os arquivos com a codificaÃ§Ã£o correta para o CMD
Write-Host "Baixando os arquivos do inventory-machine..." -ForegroundColor Cyan

# Os scripts .ps1 podem ser baixados normalmente
Invoke-WebRequest $urlinitFile -OutFile $initFile

# 3. Adiciona ao PATH do UsuÃ¡rio (se jÃ¡ nÃ£o estiver lÃ¡)
$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($oldPath -notlike "*$installDir*") {
    Write-Host "`nConfigurando variaveis de ambiente..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$oldPath;$installDir", "User")
}

Write-Host "`nInstalacao concluida!" -ForegroundColor Green
Write-Host "`nCriando atalho na Area de Trabalho..." -ForegroundColor yellow

# criaÃ§Ã£o do atalho na area de trabalho

$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [System.Environment]::GetFolderPath("Desktop")

# 1. Definimos o caminho completo do atalho primeiro
$ShortcutPath = Join-Path $DesktopPath "inventario.lnk"

# 2. Criamos o objeto de atalho
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)

# 3. Configuramos as propriedades
$Shortcut.TargetPath = "powershell.exe"
# Usamos "" para garantir que o caminho do arquivo fique entre aspas mesmo com espaÃ§os
# $Shortcut.Arguments = "-WindowStyle Hidden -File ""$installDir\interfaceGui.ps1"""
$Shortcut.Arguments = "-File ""$installDir\inventario.ps1"""
$Shortcut.WorkingDirectory = $installDir
$Shortcut.IconLocation = "shell32.dll,21" 
$Shortcut.Save()

Write-Host "`nAtalho criado na Area de Trabalho com sucesso!" -ForegroundColor Green
Write-Host "`nPressione Enter para fechar o terminal..." -ForegroundColor Green