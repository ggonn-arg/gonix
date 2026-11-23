# ============================================================
#  Backup.ps1 - Historial, deshacer y punto de restauración
# ============================================================
#  Cada cambio se guarda en historial.json con lo necesario para
#  revertirlo. Los cambios hechos en una misma operación comparten
#  el mismo "Lote", y se deshacen juntos.
# ============================================================

$script:LoteActual = $null

function Get-HistoryPath {
    $base = if ($env:GONIX_TEST_DATA_ROOT) {
        $env:GONIX_TEST_DATA_ROOT
    } else {
        Join-Path $env:ProgramData 'Gonix'
    }
    if (-not (Test-Path -LiteralPath $base)) {
        New-Item -ItemType Directory -Path $base -Force | Out-Null
    }
    Join-Path $base 'historial.json'
}

function Start-Lote {
    $script:LoteActual = (Get-Date).ToString('yyyyMMdd-HHmmss')
}

function Read-History {
    $p = Get-HistoryPath
    if (-not (Test-Path -LiteralPath $p)) { return @() }
    try {
        $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        $parsed = ConvertFrom-Json -InputObject $raw
        $lista = @()
        foreach ($e in $parsed) { $lista += $e }
        return $lista
    }
    catch { return @() }
}

function Write-History {
    param($Lista)
    $p = Get-HistoryPath
    $parent = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $arr = @($Lista | Where-Object { $_ })
    if ($arr.Count -eq 0) {
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
        return
    }
    $json = ConvertTo-Json -InputObject $arr -Depth 6
    Set-Content -LiteralPath $p -Value $json -Encoding UTF8
}

function Add-History {
    param([hashtable]$Datos)
    $entrada = [ordered]@{
        Lote  = $script:LoteActual
        Fecha = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    foreach ($k in $Datos.Keys) { $entrada[$k] = $Datos[$k] }
    $lista = @(Read-History)
    $lista += [pscustomobject]$entrada
    Write-History -Lista $lista
}

# Devuelve los lotes del historial, del más nuevo al más viejo
function Get-Lotes {
    $todas = @(Read-History)
    if ($todas.Count -eq 0) { return @() }
    $res = @()
    foreach ($g in @($todas | Group-Object -Property Lote)) {
        $ids = @($g.Group | ForEach-Object { $_.TweakId } | Where-Object { $_ } | Select-Object -Unique)
        $nombres = @()
        foreach ($id in $ids) {
            $t = Get-TweakById -Id $id
            if ($t) { $nombres += $t.nombre } else { $nombres += $id }
        }
        $res += [pscustomobject]@{
            Lote    = $g.Name
            Fecha   = $g.Group[0].Fecha
            Cambios = $g.Count
            Tweaks  = $ids.Count
            Nombres = ($nombres -join ', ')
        }
    }
    return @($res | Sort-Object -Property Fecha -Descending)
}
function Undo-Lote {
    param([string]$Lote)
    $todas = @(Read-History)
    $del = @($todas | Where-Object { $_.Lote -eq $Lote })
    $fallidas = @()
    $ok = 0

    for ($i = $del.Count - 1; $i -ge 0; $i--) {
        $e = $del[$i]
        try {
            if ($e.Tipo -eq 'registro') {
                if (-not $e.Existia) {
                    Remove-ItemProperty -LiteralPath $e.Ruta -Name $e.Nombre -ErrorAction SilentlyContinue
                }
                else {
                    $tipo = $e.TipoValor
                    if (-not $tipo) { $tipo = 'DWord' }
                    Set-ItemProperty -LiteralPath $e.Ruta -Name $e.Nombre -Value $e.ValorAnterior -Type $tipo -Force -ErrorAction Stop
                }
            }
            elseif ($e.Tipo -eq 'comando') {
                # Las entradas antiguas con tipo "comando" ya no son ejecutables.
                throw "Entrada de historial antigua sin deshacer seguro."
            }
            elseif ($e.Tipo -eq 'accion') {
                Invoke-GonixUndoAction -Accion $e.Accion
            }
            $ok++
        }
        catch {
            $fallidas += $e
            Write-Host "   [X] No se pudo revertir '$($e.TweakId)': $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    $resto = @($todas | Where-Object { $_.Lote -ne $Lote })
    Write-History -Lista ($resto + $fallidas)
    return $ok
}

function New-GonixRestorePoint {
    Write-Host '   Creando punto de restauración...' -ForegroundColor DarkGray
    try {
        Checkpoint-Computer -Description 'Gonix - antes de aplicar cambios' `
            -RestorePointType MODIFY_SETTINGS `
            -WarningVariable aviso -WarningAction SilentlyContinue -ErrorAction Stop
        if ($aviso) {
            Write-Host "   [!] No se creó: $($aviso -join ' ')" -ForegroundColor Yellow
            return $false
        }
        Write-Host '   [OK] Punto de restauración creado.' -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host '   [!] No se pudo crear el punto de restauración.' -ForegroundColor Yellow
        Write-Host '       (Puede que la Protección del sistema esté desactivada, o que ya exista' -ForegroundColor DarkGray
        Write-Host '        uno de las últimas 24 horas.)' -ForegroundColor DarkGray
        return $false
    }
}
