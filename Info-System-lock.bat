@echo off
set "COMMIT=3a7352d8690046c4e7c0d79c24cae76ccd8679c6"

start powershell -noexit -command "Invoke-Expression (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/%COMMIT%/info-sistema.ps1' -UseBasicParsing).Content"