@echo off
title Gonix
rem Doble clic para abrir Gonix. Pide permisos de administrador por su cuenta.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Gonix.ps1"
if errorlevel 1 pause
