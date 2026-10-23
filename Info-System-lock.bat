@echo off
set "COMMIT=8c7b257f266e1e8895db6a4dbaed83c9cda9da6e"

start powershell -noexit -command "Invoke-Expression (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/%COMMIT%/info-sistema.ps1' -UseBasicParsing).Content"