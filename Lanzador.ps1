#Requires -Version 5.1
<#
.SYNOPSIS
    Lanzador remoto de Gonix.
.DESCRIPTION
    Descarga la última versión de Gonix desde GitHub y la ejecuta.
    No requiere instalación.
#>

# 1. Comprobar Administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "  [!] Se necesitan permisos de administrador." -ForegroundColor Yellow
    Write-Host "      Relanzando..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/TU_USUARIO/TU_REPO/main/Lanzador.ps1 | iex`""
    exit
}

# 2. Configuración de la descarga (Aquí irá tu URL de GitHub)
$urlZip = "https://github.com/TU_USUARIO/TU_REPO/archive/refs/heads/main.zip"
$carpetaDestino = Join-Path $env:TEMP "Gonix"

Write-Host "`n  ⚡ Iniciando Gonix..." -ForegroundColor Cyan
Write-Host "  Descargando archivos necesarios..." -ForegroundColor Gray

# 3. Limpiar versiones anteriores
if (Test-Path $carpetaDestino) {
    Remove-Item -Path $carpetaDestino -Recurse -Force -ErrorAction SilentlyContinue
}

# 4. Descargar y extraer
try {
    $zipTemp = Join-Path $env:TEMP "gonix_temp.zip"
    Invoke-WebRequest -Uri $urlZip -OutFile $zipTemp -UseBasicParsing
    Expand-Archive -Path $zipTemp -DestinationPath $carpetaDestino -Force
    Remove-Item $zipTemp -Force

    # 5. Buscar el ejecutable dentro de la carpeta extraída
    # (GitHub añade el nombre de la rama al extraer, ej: Gonix-main)
    $carpetaReal = Get-ChildItem -Path $carpetaDestino -Directory | Select-Object -First 1
    $scriptPath = Join-Path $carpetaReal.FullName "Gonix.ps1"

    if (Test-Path $scriptPath) {
        # 6. Ejecutar Gonix
        & $scriptPath
    } else {
        Write-Host "  [X] Error: No se encontró Gonix.ps1 en el paquete descargado." -ForegroundColor Red
        Pause
    }
}
catch {
    Write-Host "  [X] Error al descargar: $($_.Exception.Message)" -ForegroundColor Red
    Pause
}
finally {
    # 7. Limpiar rastro al salir
    if (Test-Path $carpetaDestino) {
        Remove-Item -Path $carpetaDestino -Recurse -Force -ErrorAction SilentlyContinue
    }
}