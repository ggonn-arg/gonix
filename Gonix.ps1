#Requires -Version 5.1
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
