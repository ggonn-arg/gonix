<<<<<<< HEAD
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
=======
﻿# Gonix - lanzador remoto (no instala nada).
# Uso, en PowerShell como administrador:
#   irm https://raw.githubusercontent.com/ggonn-arg/gonix/main/Lanzador.ps1 | iex
# Para una version fija:  $env:GONIX_REF = 'v1.0.0'; irm <url-del-tag>/Lanzador.ps1 | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
$repo = 'ggonn-arg/gonix'
$ref  = if ($env:GONIX_REF) { $env:GONIX_REF } else { 'main' }

if ($ref -notmatch '^[A-Za-z0-9._/-]+$') { Write-Host '  [X] GONIX_REF invalido.' -ForegroundColor Red; return }

# 1. Administrador
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host '  [!] Se necesitan permisos de administrador. Relanzando...' -ForegroundColor Yellow
    $urlLanzador = "https://raw.githubusercontent.com/$repo/$ref/Lanzador.ps1"
    $cmd = "`$env:GONIX_REF='$ref'; irm $urlLanzador | iex"
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
    return
>>>>>>> a6dfffd7622dd4f687b104b0df2867a126c36b36
}
$carpetaDestino = Join-Path $env:TEMP ("Gonix-{0}" -f [guid]::NewGuid())
$zipTemp = Join-Path $env:TEMP ("gonix-{0}.zip" -f [guid]::NewGuid())

<<<<<<< HEAD
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
=======
# 2. Descarga a una carpeta temporal unica
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$base = Join-Path $env:TEMP ('gonix_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $base | Out-Null
$zip = Join-Path $base 'gonix.zip'

Write-Host "`n  Iniciando Gonix ($ref)..." -ForegroundColor Cyan
Write-Host '  Descargando archivos...' -ForegroundColor Gray

try {
    Invoke-WebRequest -Uri "https://github.com/$repo/archive/$ref.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $base -Force
    Remove-Item $zip -Force

    $carpeta = Get-ChildItem -LiteralPath $base -Directory | Select-Object -First 1
    $script  = Join-Path $carpeta.FullName 'Gonix.ps1'
    if (-not (Test-Path -LiteralPath $script)) { throw 'No se encontro Gonix.ps1 en el paquete descargado.' }

    # Proceso hijo con Windows PowerShell 5.1 y sin depender de la politica de ejecucion
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
}
catch {
    Write-Host "  [X] Error: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host '  Enter para salir' | Out-Null
}
finally {
    # Solo se borra el codigo descargado; el historial vive en %ProgramData%\Gonix
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
>>>>>>> a6dfffd7622dd4f687b104b0df2867a126c36b36
}
