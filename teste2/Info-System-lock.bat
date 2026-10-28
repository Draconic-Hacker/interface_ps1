@echo off
:: Defina a pasta de destino (Ex: C:\Scripts ou %USERPROFILE%\Desktop\Scripts)
set "PASTA_DESTINO=C:\relatorioScripts"

:: Cria a pasta caso ela não exista
if not exist "%PASTA_DESTINO%" mkdir "%PASTA_DESTINO%"

:: Baixa e executa o info-sistema.ps1
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/refs/heads/dev-inv/info-sistema/info-sistema.ps1' -OutFile '%PASTA_DESTINO%\info-sistema.ps1'"
powershell -ExecutionPolicy Bypass -File "%PASTA_DESTINO%\info-sistema.ps1"

timeout /t 3

:: Baixa o uninstall.ps1 (fica guardado na mesma pasta para quando precisar)
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/refs/heads/dev-inv/info-sistema/uninstall.ps1' -OutFile '%PASTA_DESTINO%\uninstall.ps1'"
powershell -ExecutionPolicy Bypass -File "%PASTA_DESTINO%\uninstall.ps1"

timeout /t 3 && exit