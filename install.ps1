# Caminho em AppData (C:\Users\Usuario\AppData\Roaming\browser-files)
$installDir = Join-Path $env:APPDATA "browser-files"

$interfaceFile = Join-Path $installDir "interfaceGui.ps1"
$updateFile = Join-Path $installDir "update.ps1"
$uninstallFile = Join-Path $installDir "uninstall.ps1"


$urlInterface = "https://raw.githubusercontent.com/Draconic-Hacker/scripts-batch/refs/heads/master/interfaceGui.ps1"
$urlUpdate = "https://raw.githubusercontent.com/Draconic-Hacker/scripts-batch/refs/heads/master/update.ps1"
$urlUninstall = "https://raw.githubusercontent.com/Draconic-Hacker/scripts-batch/refs/heads/master/uninstall.ps1"

# 1. Cria a pasta se não existir
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# 2. Baixa os arquivos com a codificação correta para o CMD
Write-Host "Baixando os arquivos do browser-files..." -ForegroundColor Cyan

# Os scripts .ps1 podem ser baixados normalmente
Invoke-WebRequest -Uri $urlInterface -OutFile $interfaceFile
Invoke-WebRequest -Uri $urlUninstall -OutFile $uninstallFile
Invoke-WebRequest -Uri $urlUpdate -OutFile $updateFile

Write-Host "`nVerificando motor de renderização (WebView2)..." -ForegroundColor Cyan

# Verifica se o Runtime já está instalado no Windows
$isInstalled = Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F1113F6E-3E03-4435-89F3-91701048E59E}"

if (-not $isInstalled) {
    Write-Host "`nWebView2 não encontrado. Baixando instalador oficial..." -ForegroundColor Yellow
    $webClient = New-Object System.Net.WebClient
    $bootstrapperPath = Join-Path $env:TEMP "MicrosoftEdgeWebview2Setup.exe"
    
    # URL oficial do instalador "Evergreen" da Microsoft
    $urlMotor = "https://go.microsoft.com"
    $webClient.DownloadFile($urlMotor, $bootstrapperPath)
    
    Write-Host "Instalando WebView2 Runtime (isso pode levar um minuto)..." -ForegroundColor Cyan
    Start-Process -FilePath $bootstrapperPath -ArgumentList "/silent", "/install" -Wait
    Remove-Item $bootstrapperPath
} else {
    Write-Host "`nWebView2 já está presente no sistema." -ForegroundColor Green
}

# 3. Adiciona ao PATH do Usuário (se já não estiver lá)
$oldPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($oldPath -notlike "*$installDir*") {
    Write-Host "`nConfigurando variaveis de ambiente..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$oldPath;$installDir", "User")
}

Write-Host "`nInstalacao concluida!" -ForegroundColor Green
Write-Host "`nCriando atalho na Área de Trabalho..." -ForegroundColor yellow

# criação do atalho na area de trabalho

$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [System.Environment]::GetFolderPath("Desktop")

# 1. Definimos o caminho completo do atalho primeiro
$ShortcutPath = Join-Path $DesktopPath "InterfaceGUi.lnk"

# 2. Criamos o objeto de atalho
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)

# 3. Configuramos as propriedades
$Shortcut.TargetPath = "powershell.exe"
# Usamos "" para garantir que o caminho do arquivo fique entre aspas mesmo com espaços
$Shortcut.Arguments = "-WindowStyle Hidden -File ""$installDir\interfaceGui.ps1"""
$Shortcut.WorkingDirectory = $installDir
$Shortcut.IconLocation = "shell32.dll,21" 
$Shortcut.Save()

Write-Host "`nAtalho criado na Área de Trabalho com sucesso!" -ForegroundColor Green
Write-Host "`nPressione Enter para fechar o terminal..." -ForegroundColor Green
Read-Host | Out-Null
exit
