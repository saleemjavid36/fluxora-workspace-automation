
@echo off
title Close Fluxora Workspace

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0Close-Fluxora-Workspace.ps1"

exit /b
