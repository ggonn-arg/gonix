#Requires -Version 5.1
<#
.SYNOPSIS
    Gonix - Optimizador de Windows 11 en PowerShell
.DESCRIPTION
    Herramienta TUI para aplicar tweaks de privacidad, rendimiento y más.
.NOTES
    Autor: Gon (gonnsttar)
    Versión: 0.1
#>

# --- Comprobar permisos de administrador ---
$esAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $esAdmin) {
    Write-Host ""
    Write-Host "  [!] Gonix necesita permisos de administrador." -ForegroundColor Yellow
    Write-Host "      Relanzando con privilegios elevados..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# --- Cargar módulos ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\lib\Helpers.ps1"
. "$scriptDir\lib\UI.ps1"
. "$scriptDir\lib\Core.ps1"

# --- Arrancar la interfaz ---
Show-MainMenu