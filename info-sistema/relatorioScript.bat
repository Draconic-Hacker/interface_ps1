
@echo off
setlocal

:: Pasta onde os scripts serao armazenados
set "PASTA_DESTINO=C:\relatorioScripts"

:: URLs dos scripts no repositorio
set "URL_RELATORIO=https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/refs/heads/dev-inv/info-sistema/info-sistema.ps1"
set "URL_UNINSTALL=https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/refs/heads/dev-inv/info-sistema/uninstall.ps1"

:: Cria a pasta de destino
if not exist "%PASTA_DESTINO%" mkdir "%PASTA_DESTINO%"

:: Baixa o script de inventario
echo Baixando script de inventario...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%URL_RELATORIO%' -OutFile '%PASTA_DESTINO%\info-sistema.ps1'"

if errorlevel 1 goto erro_download

:: Baixa o desinstalador
echo Baixando desinstalador...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%URL_UNINSTALL%' -OutFile '%PASTA_DESTINO%\uninstall.ps1'"

if errorlevel 1 goto erro_download

:: Executa o relatorio UMA unica vez
echo.
echo Iniciando coleta de inventario...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PASTA_DESTINO%\info-sistema.ps1"

:: Executa o desinstalador depois que o relatorio terminar
echo.
echo Limpando arquivos temporarios...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PASTA_DESTINO%\uninstall.ps1"

:: Aguarda brevemente antes de excluir o inicializador
echo.
echo Processo finalizado. Este inicializador sera removido.
timeout /t 2 /nobreak >nul

:: Exclui o proprio arquivo BAT
del "%~f0"
exit /b

:erro_download
echo.
echo ERRO: Nao foi possivel baixar um dos scripts.
echo Verifique a conexao com a internet e tente novamente.
pause
exit /b 1
