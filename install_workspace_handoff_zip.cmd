@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-workspace-handoff.ps1" -ZipPath "%~1" -ProjectsRoot "%~2"
exit /b %ERRORLEVEL%
