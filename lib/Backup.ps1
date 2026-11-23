# ============================================================
#  Backup.ps1 - Historial, deshacer y punto de restauración
# ============================================================
#  Cada cambio se guarda en %ProgramData%\Gonix\historial.json con lo
#  necesario para revertirlo. Los cambios de una misma operación
#  comparten "Lote" y se deshacen juntos.
#  El historial NO se ejecuta nunca como código: el deshacer solo
#  usa acciones conocidas (registro y manejadores internos).
# ============================================================

$script:LoteActual = $null
$script:Pendientes = New-Object System.Collections.ArrayList

function Get-HistoryPath { Join-Path (Get-DataDir) 'historial.json' }

function Start-Lote {
    $script:LoteActual = [guid]::NewGuid().ToString('N')
    $script:Pendientes.Clear()
}

function Read-History {
    $p = Get-HistoryPath
    if (-not (Test-Path -LiteralPath $p)) { return @() }
    try {
        $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        $historial = $raw | ConvertFrom-Json
        if ($historial -is [array]) {
            foreach ($entrada in $historial) { Write-Output $entrada }
        }
        else {
            Write-Output $historial
        }
    }
    catch {
        try { Move-Item -LiteralPath $p -Destination ("$p.corrupto-" + (Get-Date -Format 'yyyyMMddHHmmss')) -Force } catch {}
        Write-Warn 'El historial estaba dañado: se guardó una copia aparte y se empezó uno nuevo.'
        return @()
    }
}

function Write-History {
    param($Lista)
    $p = Get-HistoryPath
    $arr = @($Lista | Where-Object { $_ })
    if ($arr.Count -eq 0) {
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
        return
    }
    $json = ConvertTo-Json -InputObject $arr -Depth 8
    $tmp = "$p.tmp"
    Set-Content -LiteralPath $tmp -Value $json -Encoding UTF8
    [System.IO.File]::Copy($tmp, $p, $true)
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
}

# Acumula en memoria; Save-History lo escribe a disco de una sola vez
function Add-History {
    param([hashtable]$Datos)
    $entrada = [ordered]@{
        Lote  = $script:LoteActual
        Fecha = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }
    foreach ($k in $Datos.Keys) { $entrada[$k] = $Datos[$k] }
    [void]$script:Pendientes.Add([pscustomobject]$entrada)
}

function Save-History {
    if ($script:Pendientes.Count -eq 0) { return }
    $todas = @(Read-History) + @($script:Pendientes.ToArray())
    Write-History -Lista $todas
    $script:Pendientes.Clear()
}

# Lotes del historial, del más nuevo al más viejo
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
        
        # Forzamos a que el Lote sea un string plano, no un objeto
        $nombreLote = [string]$g.Name
        if ($nombreLote -eq "System.Object[]") { $nombreLote = "Lote sin nombre" }

        $res += [pscustomobject]@{
            Lote    = $nombreLote
            Fecha   = $g.Group[0].Fecha
            Cambios = $g.Count
            Tweaks  = $ids.Count
            Nombres = ($nombres -join ', ')
        }
    }
    return @($res | Sort-Object -Property Fecha -Descending)
}

function Invoke-HistoryUndoEntry {
    param($Entrada)

    switch ($Entrada.Tipo) {
        'registro' {
            if ($Entrada.Existia) {
                $tipo = if ($Entrada.TipoValor) { $Entrada.TipoValor } else { 'DWord' }
                Set-RegValue -Ruta $Entrada.Ruta -Nombre $Entrada.Nombre -Valor $Entrada.ValorAnterior -Tipo $tipo
            }
            else {
                Remove-RegValue -Ruta $Entrada.Ruta -Nombre $Entrada.Nombre
            }
        }
        'accion' {
            $h = $script:Acciones[$Entrada.Accion]
            if (-not $h) { throw "Acción desconocida: $($Entrada.Accion)" }
            $sb = $h.Undo
            [void](& $sb $Entrada.Datos)
        }
        default { throw 'Entrada de historial inválida (sin tipo).' }
    }
}

function Undo-Tweak {
    param([string]$TweakId)

    $todas = @(Read-History)
    $ultimoCandidato = $null
    foreach ($entrada in $todas) {
        if ($entrada.TweakId -eq $TweakId) { $ultimoCandidato = $entrada }
    }
    if (-not $ultimoCandidato) {
        return [pscustomobject]@{ Ok = 0; Fallos = 0; Total = 0 }
    }

    $lote = [string]$ultimoCandidato.Lote
    $indices = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $todas.Count; $i++) {
        if ($todas[$i].TweakId -eq $TweakId -and [string]$todas[$i].Lote -eq $lote) {
            $indices.Add($i)
        }
    }

    $revertidos = @{}
    $fallos = 0
    for ($i = $indices.Count - 1; $i -ge 0; $i--) {
        $indice = $indices[$i]
        $entrada = $todas[$indice]
        try {
            Invoke-HistoryUndoEntry -Entrada $entrada
            $revertidos[$indice] = $true
        }
        catch {
            $fallos++
            Write-Fail "No se pudo desactivar '$TweakId': $($_.Exception.Message)"
            Write-Log ('TOGGLE FALLO {0}: {1}' -f $TweakId, $_.Exception.Message)
        }
    }

    $resto = @()
    for ($i = 0; $i -lt $todas.Count; $i++) {
        if (-not $revertidos.ContainsKey($i)) { $resto += $todas[$i] }
    }
    Write-History -Lista $resto
    $ok = $indices.Count - $fallos
    Write-Log "TOGGLE $TweakId : $ok ok, $fallos con error"
    return [pscustomobject]@{ Ok = $ok; Fallos = $fallos; Total = $indices.Count }
}

function Undo-Lote {
    param([string]$Lote)
    $todas = @(Read-History)
    $del = @($todas | Where-Object { $_.Lote -eq $Lote })
    $fallidas = New-Object System.Collections.ArrayList
    $ok = 0

    for ($i = $del.Count - 1; $i -ge 0; $i--) {
        $e = $del[$i]
        try {
            Invoke-HistoryUndoEntry -Entrada $e
            $ok++
        }
        catch {
            [void]$fallidas.Add($e)
            Write-Fail "No se pudo revertir '$($e.TweakId)': $($_.Exception.Message)"
            Write-Log "UNDO FALLO $($e.TweakId): $($_.Exception.Message)"
        }
    }

    $resto = @($todas | Where-Object { $_.Lote -ne $Lote })
    Write-History -Lista (@($resto) + @($fallidas.ToArray()))
    Write-Log "UNDO lote $Lote : $ok ok, $($fallidas.Count) con error"
    return [pscustomobject]@{ Ok = $ok; Fallos = $fallidas.Count; Total = $del.Count }
}

# ---------- Punto de restauración ----------
function New-GonixRestorePoint {
    Write-Info 'Creando punto de restauración (puede tardar unos segundos)...'
    for ($intento = 1; $intento -le 2; $intento++) {
        try {
            Checkpoint-Computer -Description 'Gonix - antes de aplicar cambios' `
                -RestorePointType MODIFY_SETTINGS `
                -WarningVariable aviso -WarningAction SilentlyContinue -ErrorAction Stop
            if ($aviso) {
                Write-Warn "No se creó: $($aviso -join ' ')"
                Write-Info '(Windows permite un punto de restauración cada 24 horas.)'
                return $false
            }
            Write-Ok 'Punto de restauración creado.'
            Write-Log 'Punto de restauración creado'
            return $true
        }
        catch {
            if ($intento -eq 1) {
                Write-Warn 'No se pudo crear. Puede que la Protección del sistema esté desactivada.'
                if (Confirm-Gonix "¿Activarla en $($env:SystemDrive) y reintentar?") {
                    try { Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction Stop }
                    catch { Write-Fail "No se pudo activar: $($_.Exception.Message)"; return $false }
                    continue
                }
            }
            else { Write-Fail "Falló: $($_.Exception.Message)" }
            return $false
        }
    }
    return $false
}

function Show-RestorePointMenu {
    Write-Banner
    Write-Host '   --- Punto de restauración ---' -ForegroundColor Magenta
    Write-Host ''
    [void](New-GonixRestorePoint)
    Write-Host ''
    Wait-Enter
}
