#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'ggonn-arg/gonix'
$ref = 'v0.1'
$urlBase = "https://github.com/$repo/releases/download/$ref"
$zipUrl = "$urlBase/gonix.zip"
$hashUrl = "$urlBase/gonix.zip.sha256"

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $esAdmin) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$base = Join-Path $env:TEMP ("gonix-{0}" -f [guid]::NewGuid())
$zip = Join-Path $env:TEMP ("gonix-{0}.zip" -f [guid]::NewGuid())
$checksum = $zip + '.sha256'

try {
    New-Item -ItemType Directory -Path $base -Force | Out-Null
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
    Invoke-WebRequest -Uri $hashUrl -OutFile $checksum -UseBasicParsing

    $expected = (Get-Content -LiteralPath $checksum -Raw -Encoding ASCII).Trim()
    if ($expected -notmatch '^[A-Fa-f0-9]{64}$') { throw 'El checksum descargado no es valido.' }
    $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected.ToLowerInvariant()) { throw 'Checksum SHA256 incorrecto.' }

    Expand-Archive -LiteralPath $zip -DestinationPath $base -Force
    $script = Join-Path $base 'Gonix.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        $folder = Get-ChildItem -LiteralPath $base -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'Gonix.ps1') } |
            Select-Object -First 1
        if ($folder) { $script = Join-Path $folder.FullName 'Gonix.ps1' }
    }
    if (-not (Test-Path -LiteralPath $script)) { throw 'No se encontro Gonix.ps1.' }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
}
catch {
    Write-Host "  [X] $($_.Exception.Message)" -ForegroundColor Red
    Read-Host '  Enter para salir' | Out-Null
}
finally {
    Remove-Item -LiteralPath $zip -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $checksum -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $base -Force -Recurse -ErrorAction SilentlyContinue
}
