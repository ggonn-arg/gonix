# ============================================================
#  Helpers.ps1 - Utilidades comunes (mensajes, registro, servicios)
# ============================================================

function Get-GonixVersion { '1.0.0' }

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Carpeta de datos persistente (historial y log). No se borra al cerrar Gonix.
function Get-DataDir {
    $d = if ($env:GONIX_TEST_DATA_ROOT) {
        $env:GONIX_TEST_DATA_ROOT
    } else {
        Join-Path $env:ProgramData 'Gonix'
    }
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}

function Write-Log {
    param([string]$Mensaje)
    try {
        $l = Join-Path (Get-DataDir) 'gonix.log'
        Add-Content -LiteralPath $l -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Mensaje) -Encoding UTF8
    } catch {}
}

# ---------- Mensajes ----------
function Write-Ok   { param([string]$T) Write-Host "   [OK] $T" -ForegroundColor Green }
function Write-Warn { param([string]$T) Write-Host "   [!]  $T" -ForegroundColor Yellow }
function Write-Fail { param([string]$T) Write-Host "   [X]  $T" -ForegroundColor Red }
function Write-Info { param([string]$T) Write-Host "   $T" -ForegroundColor DarkGray }

function Write-MenuItem {
    param([string]$Tecla, [string]$Texto, [string]$Color = 'White')
    Write-Host ('   [{0}] ' -f $Tecla) -ForegroundColor Cyan -NoNewline
    Write-Host $Texto -ForegroundColor $Color
}

function Confirm-Gonix {
    param([string]$Pregunta)
    $r = Read-Host "   $Pregunta (s/n)"
    return ($r -match '^(s|si|sí|y|yes)$')
}

function Wait-Enter { [void](Read-Host '   Enter para continuar') }

# Convierte "1,3,5-7" en índices base 0 válidos (sin repetir, dentro de 1..Max)
function ConvertTo-Indices {
    param([string]$Texto, [int]$Max)
    $res = New-Object System.Collections.Generic.List[int]
    foreach ($p in ($Texto -split '[,\s]+')) {
        if ($p -match '^(\d{1,4})-(\d{1,4})$') {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            for ($i = $a; $i -le $b; $i++) {
                if ($i -ge 1 -and $i -le $Max -and -not $res.Contains($i - 1)) { $res.Add($i - 1) }
            }
        }
        elseif ($p -match '^\d{1,4}$') {
            $n = [int]$p
            if ($n -ge 1 -and $n -le $Max -and -not $res.Contains($n - 1)) { $res.Add($n - 1) }
        }
    }
    return , @($res.ToArray())
}

# ---------- JSON (siempre UTF-8, con o sin BOM) ----------
function Read-JsonArray {
    param([string]$Ruta)
    $raw = Get-Content -LiteralPath $Ruta -Raw -Encoding UTF8
    return , @($raw | ConvertFrom-Json)
}

function Read-JsonObject {
    param([string]$Ruta)
    $raw = Get-Content -LiteralPath $Ruta -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}

# ---------- Registro ----------
function ConvertTo-RegistryValue {
    param($Valor, [string]$Tipo = 'DWord')
    switch ($Tipo) {
        'DWord' {
            $n = [int64]$Valor
            if ($n -gt [int32]::MaxValue) { $n = $n - 4294967296 }   # 4294967295 -> -1 (0xFFFFFFFF)
            return [int32]$n
        }
        'QWord'       { return [int64]$Valor }
        'Binary'      { return , [byte[]]@($Valor) }
        'MultiString' { return , [string[]]@($Valor) }
        default       { return [string]$Valor }
    }
}

function Get-RegState {
    param([string]$Ruta, [string]$Nombre)
    $r = [pscustomobject]@{ Existe = $false; Valor = $null; Tipo = $null }
    try {
        if (-not (Test-Path -LiteralPath $Ruta)) { return $r }
        $k = Get-Item -LiteralPath $Ruta -ErrorAction Stop
        if (@($k.GetValueNames()) -contains $Nombre) {
            $r.Existe = $true
            $r.Valor  = $k.GetValue($Nombre, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $r.Tipo   = $k.GetValueKind($Nombre).ToString()
        }
    } catch {}
    return $r
}

function Test-RegValueEqual {
    param($Actual, $Deseado, [string]$Tipo = 'DWord')
    $d = ConvertTo-RegistryValue -Valor $Deseado -Tipo $Tipo
    if ($d -is [array]) { return ((@($Actual) -join ',') -eq (@($d) -join ',')) }
    return ($Actual -eq $d)
}

function Set-RegValue {
    param([string]$Ruta, [string]$Nombre, $Valor, [string]$Tipo = 'DWord')
    if (-not (Test-Path -LiteralPath $Ruta)) { New-Item -Path $Ruta -Force -ErrorAction Stop | Out-Null }
    $v = ConvertTo-RegistryValue -Valor $Valor -Tipo $Tipo
    Set-ItemProperty -LiteralPath $Ruta -Name $Nombre -Value $v -Type $Tipo -Force -ErrorAction Stop
}

function Remove-RegValue {
    param([string]$Ruta, [string]$Nombre)
    if (Test-Path -LiteralPath $Ruta) {
        Remove-ItemProperty -LiteralPath $Ruta -Name $Nombre -Force -ErrorAction SilentlyContinue
    }
}

# ---------- Servicios (lee/restaura el modo de inicio real, incluido "retrasado") ----------
function Get-ServiceStartup {
    param([string]$Nombre)
    $k = "HKLM:\SYSTEM\CurrentControlSet\Services\$Nombre"
    if (-not (Test-Path -LiteralPath $k)) { return $null }
    $p = Get-ItemProperty -LiteralPath $k
    $start = [int]$p.Start
    $delayed = $false
    if ($start -eq 2 -and ($p.PSObject.Properties.Name -contains 'DelayedAutostart') -and [int]$p.DelayedAutostart -eq 1) { $delayed = $true }
    return [pscustomobject]@{ Start = $start; Delayed = $delayed }
}

function Set-ServiceStartup {
    param([string]$Nombre, [int]$Start, [bool]$Delayed = $false)
    $modo = switch ($Start) {
        2 { if ($Delayed) { 'delayed-auto' } else { 'auto' } }
        3 { 'demand' }
        4 { 'disabled' }
        default { throw "Modo de inicio no soportado: $Start" }
    }
    & sc.exe config $Nombre start= $modo | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "sc.exe config falló para $Nombre (código $LASTEXITCODE)" }
}

# ---------- Planes de energía ----------
function Get-ActiveSchemeGuid {
    $out = (& powercfg.exe /getactivescheme) -join ' '
    if ($out -match '([0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})') { return $Matches[1] }
    throw 'No se pudo leer el plan de energía activo.'
}
