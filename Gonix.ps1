<<<<<<< HEAD
﻿#Requires -Version 5.1
<#
.SYNOPSIS
    Gonix - Optimizador de Windows 11 en PowerShell
.DESCRIPTION
    Herramienta TUI para aplicar tweaks de privacidad, rendimiento y más.
.NOTES
    Autor: Gon (gonnsttar)
    Versión: v0.1
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
$script:GonixRoot = $scriptDir

. "$scriptDir\lib\Helpers.ps1"
. "$scriptDir\lib\Backup.ps1"  # <-- ESTA LÍNEA ES CLAVE
. "$scriptDir\lib\UI.ps1"
. "$scriptDir\lib\Core.ps1"

# --- Arrancar la interfaz ---
Show-MainMenu
=======
﻿#Requires -Version 5.1
<#
.SYNOPSIS
    Gonix - Optimizador de Windows 11 en PowerShell.
.DESCRIPTION
    Interfaz de consola para aplicar ajustes de privacidad y rendimiento
    con historial y deshacer. Los tweaks estan definidos en tweaks\*.json.
.NOTES
    Autor: Gonzalo (ggonn-arg) - Licencia MIT
#>

# --- Requisitos: Windows PowerShell 5.1 + administrador ---------------------
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($PSVersionTable.PSEdition -eq 'Core' -or -not $esAdmin) {
    if (-not $esAdmin) { Write-Host '  Gonix necesita permisos de administrador. Relanzando...' -ForegroundColor Yellow }
    $argumentos = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    try {
        if ($esAdmin) { Start-Process powershell.exe -ArgumentList $argumentos -Wait }
        else          { Start-Process powershell.exe -ArgumentList $argumentos -Verb RunAs -Wait }
    }
    catch {
        Write-Host '  [X] No se pudo abrir con permisos de administrador (cancelaste el aviso de UAC?).' -ForegroundColor Red
        Read-Host '  Enter para salir' | Out-Null
    }
    exit
}

# --- Carga de modulos -------------------------------------------------------
$script:GonixRoot = $PSScriptRoot
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $Host.UI.RawUI.WindowTitle = 'Gonix' } catch {}

. (Join-Path $PSScriptRoot 'lib\Helpers.ps1')
. (Join-Path $PSScriptRoot 'lib\Backup.ps1')
. (Join-Path $PSScriptRoot 'lib\Core.ps1')
. (Join-Path $PSScriptRoot 'lib\Mantenimiento.ps1')
. (Join-Path $PSScriptRoot 'lib\UI.ps1')

# --- Arranque ---------------------------------------------------------------
try {
    Initialize-Gonix
    Show-MainMenu
}
catch {
    Write-Fail "Error inesperado: $($_.Exception.Message)"
    Write-Log "FATAL: $($_.Exception.Message)"
    Read-Host '  Enter para salir' | Out-Null
}
>>>>>>> a6dfffd7622dd4f687b104b0df2867a126c36b36
