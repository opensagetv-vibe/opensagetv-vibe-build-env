@echo off
setlocal
python "%~dp0scripts\github-change-gate.py" --workspace-root "%~dp0..\.." %*
exit /b %ERRORLEVEL%
