#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'ggonn-arg/gonix'
$apiUrl = "https://api.github.com/repos/$repo/commits/main"

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $esAdmin) {
    Write-Host '  [X] Abrí Windows PowerShell como administrador y volvé a ejecutar el lanzador.' -ForegroundColor Red
    Read-Host '  Enter para salir' | Out-Null
    return
}

$base = Join-Path $env:TEMP ("gonix-{0}" -f [guid]::NewGuid())
$zip = Join-Path $env:TEMP ("gonix-{0}.zip" -f [guid]::NewGuid())

try {
    $commit = Invoke-RestMethod -Uri $apiUrl -Headers @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'Gonix'
    }
    $ref = [string]$commit.sha
    if ($ref -notmatch '^[A-Fa-f0-9]{40}$') { throw 'GitHub devolvió un SHA de commit inválido.' }

    $zipUrl = "https://github.com/$repo/archive/$ref.zip"
    New-Item -ItemType Directory -Path $base -Force | Out-Null
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
    Expand-Archive -LiteralPath $zip -DestinationPath $base -Force

    $script = Get-ChildItem -LiteralPath $base -Filter Gonix.ps1 -Recurse -File |
        Select-Object -First 1
    if (-not $script) { throw "No se encontró Gonix.ps1 en el commit $ref." }

    Write-Host "  Ejecutando Gonix desde el commit $ref..." -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script.FullName
}
catch {
    Write-Host "  [X] $($_.Exception.Message)" -ForegroundColor Red
    Read-Host '  Enter para salir' | Out-Null
}
finally {
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}
