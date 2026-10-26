@echo off
set "COMMIT=a6374901a4943caa939c6adc09dd5615d1b1a542"

start powershell -noexit -command "Invoke-Expression (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/%COMMIT%/info-sistema.ps1' -UseBasicParsing).Content"