@echo off

mkdir "%USERPROFILE%\Downloads\inventario"

start powershell -noexit -file "%~dp0info-sistema.ps1"