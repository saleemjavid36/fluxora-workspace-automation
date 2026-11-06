
@echo off
title Fluxora Workspace

:: Run the launcher silently in the background
start "" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Fluxora-Workspace.ps1"

exit
