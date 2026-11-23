# Gonix - lanzador remoto (no instala nada).
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
}

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
}
