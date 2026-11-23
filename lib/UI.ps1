# ============================================================
#  UI.ps1 - Interfaz de consola (menús generados desde los JSON)
# ============================================================

function Write-Banner {
    Clear-Host
    Write-Host ''
    Write-Host '   ██████╗  ██████╗ ███╗   ██╗██╗██╗  ██╗' -ForegroundColor Cyan
    Write-Host '  ██╔════╝ ██╔═══██╗████╗  ██║██║╚██╗██╔╝' -ForegroundColor Cyan
    Write-Host '  ██║  ███╗██║   ██║██╔██╗ ██║██║ ╚███╔╝ ' -ForegroundColor Cyan
    Write-Host '  ██║   ██║██║   ██║██║╚██╗██║██║ ██╔██╗ ' -ForegroundColor Cyan
    Write-Host '  ╚██████╔╝╚██████╔╝██║ ╚████║██║██╔╝ ██╗' -ForegroundColor Cyan
    Write-Host '   ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('        [ Optimizador de Windows 11 ]  v{0}' -f (Get-GonixVersion)) -ForegroundColor DarkGray
    Write-Host '   ════════════════════════════════════════════════════' -ForegroundColor DarkCyan
    Write-Host ''
}

function Show-SystemInfo {
    Write-Host "   $($script:InfoSistema)" -ForegroundColor DarkGray
    if ($script:BuildWindows -gt 0 -and $script:BuildWindows -lt 22000) {
        Write-Host '   Aviso: Gonix está pensado para Windows 11; algunos tweaks pueden no tener efecto.' -ForegroundColor Yellow
    }
    Write-Host '   ════════════════════════════════════════════════════' -ForegroundColor DarkCyan
    Write-Host ''
}

# ------------------------------------------------------------
#  Menú principal
# ------------------------------------------------------------
function Show-MainMenu {
    while ($true) {
        Write-Banner
        Show-SystemInfo
        Write-MenuItem '1' 'Perfiles (Recomendado, Gaming, Oficina, Notebook, Privacidad)'
        Write-MenuItem '2' 'Tweaks individuales'
        Write-MenuItem '3' 'Instalar aplicaciones (winget)'
        Write-MenuItem '4' 'Historial y deshacer'
        Write-MenuItem '5' 'Windows Update'
        Write-MenuItem '6' 'Limpieza y reparación'
        Write-MenuItem '7' 'Crear punto de restauración'
        Write-Host ''
        Write-MenuItem '0' 'Salir' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una opción'
        switch ($op) {
            '1' { Show-ProfilesMenu }
            '2' { Show-TweaksMenu }
            '3' { Show-AppInstaller }
            '4' { Show-HistoryMenu }
            '5' { Show-UpdateMenu }
            '6' { Show-MaintenanceMenu }
            '7' { Show-RestorePointMenu }
            '0' { Write-Host '   ¡Chau, Gon!' -ForegroundColor Cyan; return }
            default { Write-Warn 'Opción inválida.'; Start-Sleep 1 }
        }
    }
}

# ------------------------------------------------------------
#  Perfiles
# ------------------------------------------------------------
function Format-WrappedLines {
    param(
        [string]$Texto,
        [int]$Sangria = 7
    )
    if ([string]::IsNullOrWhiteSpace($Texto)) { return @() }
    $anchoVentana = try { [Console]::WindowWidth } catch { 100 }
    $maxAncho = [Math]::Max(36, $anchoVentana - $Sangria - 2)
    $prefijo = ' ' * $Sangria
    $palabras = $Texto -split '\s+'
    $lineas = New-Object System.Collections.Generic.List[string]
    $actual = ''

    foreach ($w in $palabras) {
        if ([string]::IsNullOrWhiteSpace($w)) { continue }
        $candidato = if ($actual) { "$actual $w" } else { $w }
        if ($candidato.Length -le $maxAncho) {
            $actual = $candidato
        }
        else {
            if ($actual) { $lineas.Add("$prefijo$actual") }
            $actual = $w
        }
    }
    if ($actual) { $lineas.Add("$prefijo$actual") }
    return @($lineas)
}

# ------------------------------------------------------------
#  Perfiles
# ------------------------------------------------------------
function Show-ProfilesMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Perfiles ---' -ForegroundColor Magenta
        Write-Host ''
        for ($i = 0; $i -lt $script:Perfiles.Count; $i++) {
            $p = $script:Perfiles[$i]
            Write-MenuItem ($i + 1) $p.nombre
            foreach ($l in (Format-WrappedLines -Texto $p.descripcion -Sangria 7)) {
                Write-Host $l -ForegroundColor DarkGray
            }
            Write-Host ''
        }
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí un perfil'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }
        $n = 0
        if (-not [int]::TryParse($op, [ref]$n) -or $n -lt 1 -or $n -gt $script:Perfiles.Count) {
            Write-Warn 'Opción inválida.'; Start-Sleep 1; continue
        }
        $p = $script:Perfiles[$n - 1]
        Invoke-TweakSet -Ids @($p.tweaks) -Titulo "Perfil: $($p.nombre)" -Descripcion $p.descripcion
        Write-Host ''
        Wait-Enter
    }
}

# ------------------------------------------------------------
#  Tweaks individuales (menú genérico por categoría)
# ------------------------------------------------------------
function Show-TweaksMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Tweaks individuales ---' -ForegroundColor Magenta
        Write-Host ''
        Write-MenuItem '1' ('Privacidad            ({0} tweaks)' -f @(Get-TweaksByCategory 'privacidad').Count)
        Write-MenuItem '2' ('Sistema               ({0} tweaks)' -f @(Get-TweaksByCategory 'sistema').Count)
        Write-MenuItem '3' ('Rendimiento y red     ({0} tweaks)' -f @(Get-TweaksByCategory 'rendimiento').Count)
        Write-MenuItem '4' 'Desinstalar apps preinstaladas'
        Write-MenuItem '5' ('ZONA DE PELIGRO       ({0} tweaks avanzados)' -f @(Get-TweaksByCategory 'avanzado').Count) 'Red'
        Write-MenuItem '0' 'Volver' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una categoría'
        switch ($op) {
            '1' { Show-TweakCategory -Categoria 'privacidad'  -Titulo 'Privacidad' }
            '2' { Show-TweakCategory -Categoria 'sistema'     -Titulo 'Sistema' }
            '3' { Show-TweakCategory -Categoria 'rendimiento' -Titulo 'Rendimiento y red' }
            '4' { Show-BloatwareMenu }
            '5' { Show-TweakCategory -Categoria 'avanzado' -Titulo 'ZONA DE PELIGRO' `
                    -Aviso "Pueden causar inestabilidad, calor o consumo excesivo. Solo para usuarios avanzados.`nCada cambio se puede deshacer desde el historial." }
            '0' { return }
            default { Write-Warn 'Opción inválida.'; Start-Sleep 1 }
        }
    }
}

function Show-TweakCategory {
    param([string]$Categoria, [string]$Titulo, [string]$Aviso = '')
    while ($true) {
        Write-Banner
        Write-Host "   --- $Titulo ---" -ForegroundColor Magenta
        if ($Aviso) { foreach ($l in ($Aviso -split "`n")) { Write-Host "   $l" -ForegroundColor Yellow } }
        Write-Host ''
        $lista = @(Get-TweaksByCategory $Categoria)
        for ($i = 0; $i -lt $lista.Count; $i++) {
            $t = $lista[$i]
            $e = Get-TweakAppliedState $t
            if ($e -eq $true)      { $marca = '[ON]'; $color = 'Green' }
            elseif ($e -eq $false) { $marca = '[  ]'; $color = Get-RiskColor $t }
            else                   { $marca = '[??]'; $color = Get-RiskColor $t }
            Write-Host ('   {0,2}. {1} {2}{3}' -f ($i + 1), $marca, $t.nombre, (Get-RiskSuffix $t)) -ForegroundColor $color
        }
        Write-Host ''
        Write-Info '[ON] aplicado   [  ] pendiente   [??] no se puede detectar'
        Write-Info 'Escribí números para activar o desactivar (ej: 1,3,5-7)  |  "d 3" = ver detalle del 3'
        if ($Categoria -ne 'avanzado') { Write-Info '"A" = aplicar todos los pendientes de riesgo bajo' }
        Write-Info 'Enter o 0 para volver'
        Write-Host ''
        $op = (Read-Host '   Tu elección').Trim()
        if ($op -eq '' -or $op -eq '0') { return }

        if ($op -match '^[dD]\s*(\d{1,3})$') {
            $n = [int]$Matches[1]
            if ($n -ge 1 -and $n -le $lista.Count) { Show-TweakDetail $lista[$n - 1] } else { Write-Warn 'Número inválido.' }
            Wait-Enter
            continue
        }

        if ($op -match '^[aA]$') {
            if ($Categoria -eq 'avanzado') { Write-Warn 'En la zona de peligro se elige de a uno.'; Start-Sleep 2; continue }
            $ids = @($lista | Where-Object { $_.riesgo -eq 'bajo' } | ForEach-Object { $_.id })
            Invoke-TweakSet -Ids $ids -Titulo "${Titulo}: todos los de riesgo bajo"
            Write-Host ''; Wait-Enter
            continue
        }

        $idx = @(ConvertTo-Indices -Texto $op -Max $lista.Count)
        if ($idx.Count -eq 0) { Write-Warn 'No entendí esa selección.'; Start-Sleep 1; continue }
        $ids = @($idx | ForEach-Object { $lista[$_].id })
        Invoke-TweakSet -Ids $ids -Alternar
        Write-Host ''; Wait-Enter
    }
}

# ------------------------------------------------------------
#  Historial y deshacer
# ------------------------------------------------------------
function Show-HistoryMenu {
    while ($true) {
        Write-Banner
        Write-Host '   --- Historial y deshacer ---' -ForegroundColor Magenta
        Write-Host ''
        $lotes = @(Get-Lotes)
        if ($lotes.Count -eq 0) {
            Write-Info 'Todavía no hay cambios registrados.'
            Write-Host ''; Wait-Enter; return
        }
        for ($i = 0; $i -lt $lotes.Count; $i++) {
            $l = $lotes[$i]
            Write-Host ('   [{0}] {1}  -  {2} cambio(s)' -f ($i + 1), $l.Fecha, $l.Cambios) -ForegroundColor White
            $nombres = $l.Nombres
            if ($nombres.Length -gt 110) { $nombres = $nombres.Substring(0, 107) + '...' }
            Write-Host "       $nombres" -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Info 'Elegí el número a deshacer: se revierten todos los cambios de ese lote.'
        Write-Info 'Enter o 0 para volver.'
        $op = Read-Host '   Tu elección'
        if ([string]::IsNullOrWhiteSpace($op) -or $op -eq '0') { return }
        $n = 0
        if (-not [int]::TryParse($op, [ref]$n) -or $n -lt 1 -or $n -gt $lotes.Count) {
            Write-Warn 'Opción inválida.'; Start-Sleep 1; continue
        }
        if (-not (Confirm-Gonix "¿Deshacer el lote del $($lotes[$n - 1].Fecha)?")) { continue }
        $r = @(Undo-Lote -Lote $lotes[$n - 1].Lote) | Select-Object -Last 1
        Write-Host ''
        if ($r.Fallos -eq 0) { Write-Ok "Se revirtieron $($r.Ok) cambio(s)." }
        else { Write-Warn "Se revirtieron $($r.Ok) de $($r.Total). Los que fallaron siguen en el historial." }
        Write-Info 'Algunos cambios se ven recién al reiniciar o cerrar sesión.'
        Write-Host ''; Wait-Enter
    }
}
