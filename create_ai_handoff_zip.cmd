@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\create-ai-handoff.ps1" -ProjectRoot "%~dp0."
exit /b %ERRORLEVEL%
