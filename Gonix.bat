@echo off
title Gonix
rem Doble clic para abrir Gonix. El script pide permisos de administrador solo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Gonix.ps1"
