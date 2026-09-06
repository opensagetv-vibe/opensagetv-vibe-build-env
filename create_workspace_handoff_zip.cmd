@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\create-workspace-handoff.ps1" -ProjectsRoot "%~dp0.."
exit /b %ERRORLEVEL%
