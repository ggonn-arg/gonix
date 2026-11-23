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
    if ($script:BuildWindows -gt 0 -and $script:BuildWindows -lt 22000) {
        Write-Host '   Aviso: Gonix está pensado para Windows 11; algunos tweaks pueden no tener efecto.' -ForegroundColor Yellow
    }
}

function Show-GamingAdvisor {
    $diagnostico = Get-GamingDiagnostic

    Write-Banner
    Write-Host '   --- Asistente Gaming: recomendaciones ---' -ForegroundColor Magenta
    Write-Info 'Solo lectura: no cambia la configuración ni mide FPS.'
    Write-Host ''
    $gpuNames = @($diagnostico.GPU | ForEach-Object { $_.Nombre } | Where-Object { $_ })
    $gpuResumen = if ($gpuNames.Count -gt 0) { $gpuNames -join ', ' } else { 'No detectada' }
    Write-Host "   Equipo: $($diagnostico.TipoEquipo) | GPU: $gpuResumen" -ForegroundColor White
    Write-Host "   Modo Juego: $($diagnostico.ModoJuego)" -ForegroundColor White
    Write-Host "   Captura GameDVR: $($diagnostico.CapturaJuego)" -ForegroundColor White
    Write-Host "   HAGS: $($diagnostico.HAGS)" -ForegroundColor White
    Write-Host "   Plan de energía: $($diagnostico.PlanEnergia)" -ForegroundColor White

    Write-Host ''
    $recomendaciones = @(Get-GamingRecommendations -Diagnostico $diagnostico)
    foreach ($recomendacion in $recomendaciones) {
        $color = switch ($recomendacion.Nivel) {
            'BAJO' { 'Green' }
            'MEDIO' { 'Yellow' }
            'ALTO' { 'Red' }
            'PRECAUCIÓN' { 'Yellow' }
            default { 'Cyan' }
        }
        Write-Host ('   [{0}] {1}' -f $recomendacion.Nivel, $recomendacion.Titulo) -ForegroundColor $color
        Write-Info "Por qué: $($recomendacion.Motivo)"
        if ($recomendacion.Nivel -in @('MEDIO', 'ALTO', 'PRECAUCIÓN')) {
            Write-Warn "Ojo: $($recomendacion.Advertencia)"
        } else {
            Write-Info "Nota: $($recomendacion.Advertencia)"
        }
        Write-Host ''
    }

    foreach ($errorDiagnostico in $diagnostico.Errores) {
        Write-Warn "No se pudo leer un dato: $errorDiagnostico"
    }

    Write-Info 'Para probar una sola opción, usá Tweaks individuales; el perfil Gaming aplica el conjunto completo.'
    Write-Info 'Para medir el efecto, usá el benchmark del juego con la misma escena antes y después de un solo cambio.'
    Wait-Enter
}

# ------------------------------------------------------------
#  Menú principal
# ------------------------------------------------------------
function Show-MainMenu {
    while ($true) {
        Write-Banner
        Show-SystemInfo
        Write-Host '   ¿Qué querés hacer?' -ForegroundColor White
        Write-Host ''
        Write-Host '   OPTIMIZAR' -ForegroundColor DarkCyan
        Write-MenuItem '1' 'Aplicar un perfil (Gaming, Recomendado y más)'
        Write-MenuItem '2' 'Elegir ajustes manualmente'
        Write-MenuItem '3' 'Ver recomendaciones para juegos'
        Write-Host ''
        Write-Host '   APLICACIONES' -ForegroundColor DarkCyan
        Write-MenuItem '4' 'Instalar programas'
        Write-Host ''
        Write-Host '   MANTENIMIENTO' -ForegroundColor DarkCyan
        Write-MenuItem '5' 'Ver historial y deshacer cambios'
        Write-MenuItem '6' 'Configurar actualizaciones de Windows'
        Write-MenuItem '7' 'Limpiar y reparar Windows'
        Write-MenuItem '8' 'Crear un punto de restauración'
        Write-Host ''
        Write-MenuItem '0' 'Salir' 'DarkGray'
        Write-Host ''
        $op = Read-Host '   Elegí una opción'
        switch ($op) {
            '1' { Show-ProfilesMenu }
            '2' { Show-TweaksMenu }
            '3' { Show-GamingAdvisor }
            '4' { Show-AppInstaller }
            '5' { Show-HistoryMenu }
            '6' { Show-UpdateMenu }
            '7' { Show-MaintenanceMenu }
            '8' { Show-RestorePointMenu }
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
