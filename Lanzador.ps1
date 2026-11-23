#Requires -Version 5.1
<#
.SYNOPSIS
    Lanzador remoto de Gonix.
.DESCRIPTION
    Descarga una versión publicada de Gonix desde GitHub y verifica su SHA256.
    No requiere instalación.
#>

$version = 'v0.1'
$urlBase = "https://github.com/ggonn-arg/gonix/releases/download/$version"
$urlZip = "$urlBase/gonix.zip"
$urlChecksum = "$urlBase/gonix.zip.sha256"

# 1. Comprobar Administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  [!] Se necesitan permisos de administrador." -ForegroundColor Yellow
    Write-Host "      Relanzando..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}
$carpetaDestino = Join-Path $env:TEMP ("Gonix-{0}" -f [guid]::NewGuid())
$zipTemp = Join-Path $env:TEMP ("gonix-{0}.zip" -f [guid]::NewGuid())

Write-Host "`n  ⚡ Iniciando Gonix $version..." -ForegroundColor Cyan
Write-Host "  Descargando archivos necesarios..." -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri $urlZip -OutFile $zipTemp -UseBasicParsing
    Invoke-WebRequest -Uri $urlChecksum -OutFile ($zipTemp + '.sha256') -UseBasicParsing

    $expectedLine = (Get-Content -LiteralPath ($zipTemp + '.sha256') -Raw).Trim()
    if ($expectedLine -notmatch '^[A-Fa-f0-9]{64}') {
        throw "El archivo checksum no tiene un formato SHA256 valido."
    }

    $expectedHash = $Matches[0].ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $zipTemp -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "Checksum SHA256 invalido. Se detuvo la ejecucion por seguridad."
    }

    Expand-Archive -LiteralPath $zipTemp -DestinationPath $carpetaDestino -Force
    Remove-Item -LiteralPath $zipTemp -Force -ErrorAction SilentlyContinue

    $scriptPath = Join-Path $carpetaDestino 'Gonix.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        $carpetaReal = Get-ChildItem -LiteralPath $carpetaDestino -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'Gonix.ps1') } |
            Select-Object -First 1
        if ($null -ne $carpetaReal) {
            $scriptPath = Join-Path $carpetaReal.FullName 'Gonix.ps1'
        }
    }

    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "No se encontró Gonix.ps1 en el paquete descargado."
    }
    & $scriptPath
}
catch {
    Write-Host "  [X] Error al descargar o ejecutar Gonix: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "  Presioná Enter para cerrar"
}
finally {
    Remove-Item -LiteralPath $zipTemp -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath ($zipTemp + '.sha256') -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $carpetaDestino -Force -Recurse -ErrorAction SilentlyContinue
}
